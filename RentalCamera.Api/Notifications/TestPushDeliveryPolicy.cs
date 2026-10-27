using System.Globalization;
using System.Text.RegularExpressions;
using FirebaseAdmin.Messaging;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

/// <summary>Continuous test recipient guard on the existing outbox; no session or total quota.</summary>
public sealed class TestPushDeliveryPolicy
{
    public const string Section = "Notifications:TestDelivery";
    public const string LegacySection = "Notifications:AutomaticTestScope";
    public static readonly string[] EventCodes = [
        "CONTRACT_CREATED", "CONTRACT_SIGNED", "CONTRACT_AWAITING_HANDOVER", "CONTRACT_RENTING", "CONTRACT_COMPLETED", "CONTRACT_CANCELLED",
        "PAYMENT_CHO_THANH_TOAN", "PAYMENT_THANH_CONG", "PAYMENT_THAT_BAI", "PAYMENT_DA_HOAN",
        "EXTENSION_CHO_XAC_NHAN", "EXTENSION_CHO_KY", "EXTENSION_TU_CHOI", "EXTENSION_DA_HUY", "EXTENSION_DA_HIEU_LUC",
        "EXTENSION_HET_HAN_XU_LY", "EXTENSION_HET_HAN_KY"];
    public string AccountId { get; private init; } = "";
    public string CustomerId { get; private init; } = "";
    public string DeviceRegistrationId { get; private init; } = "";
    public string DeviceTokenHash { get; private init; } = "";
    public DateTime CutoverUtc { get; private init; }
    public bool Halted { get; private set; }
    public string? HaltReason { get; private set; }
    public string? LastProblem { get; private set; }

    // The test database must never fall back to the unrestricted drain, even if
    // somebody accidentally removes all recipient settings while PushEnabled is true.
    public static bool Configured(IConfiguration config) => config.GetSection(Section).Exists() ||
        config.GetSection(LegacySection).Exists() || !string.IsNullOrWhiteSpace(config["Notifications:TestAccountId"]) ||
        new SqlConnectionStringBuilder(config.GetConnectionString("RentalCamera") ?? "").InitialCatalog == "RentalCameraDb20_Test";

    public static TestPushDeliveryPolicy? FromConfiguration(IConfiguration config)
    {
        string? Get(string key) => config[Section + ":" + key];
        var events = (Get("AllowedEvents") ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (config.GetSection(LegacySection).Exists() || Get("Enabled") != "true" || Get("Mode") != "Continuous" ||
            config["Notifications:TestAccountId"] != "TK130ED33FD1FE41229" ||
            config["Rental:BackgroundJobsEnabled"] != "false" || config["ElectronicSignature:ReturnOtpInResponse"] != "false" ||
            Get("AccountId") != "TK130ED33FD1FE41229" || Get("CustomerId") != "KH031BC569C14B44B2A" ||
            !Guid.TryParseExact(Get("DeviceRegistrationId"), "D", out _) ||
            !Regex.IsMatch(Get("DeviceTokenHash") ?? "", "\\A[0-9A-F]{64}\\z") ||
            !DateTime.TryParseExact(Get("CutoverUtc"), "O", CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var cutover) ||
            cutover.Kind != DateTimeKind.Utc || cutover.Year < 2020 ||
            events.Length != EventCodes.Length || !events.ToHashSet(StringComparer.Ordinal).SetEquals(EventCodes)) return null;
        return new() { AccountId = Get("AccountId")!, CustomerId = Get("CustomerId")!,
            DeviceRegistrationId = Get("DeviceRegistrationId")!, DeviceTokenHash = Get("DeviceTokenHash")!, CutoverUtc = cutover };
    }

    public IQueryable<NotificationDelivery> Deliveries(IQueryable<NotificationDelivery> deliveries, IQueryable<ThongBao> notices,
        IQueryable<HopDong> contracts, IQueryable<ThanhToan> payments, IQueryable<PhuLuc> appendices)
    {
        var allowed = notices.Where(n => n.MaTaiKhoan == AccountId && n.EventKey != null && n.HanTraNhac == null &&
            n.ThoiGianGui >= CutoverUtc && n.TargetType == "HOP_DONG" && n.TargetId != null &&
            !RentalPolicy.ProtectedContracts.Contains(n.TargetId) && EventCodes.Contains(n.EventCode!) &&
            contracts.Any(h => h.MaHopDong == n.TargetId && h.MaKhachThue == CustomerId) &&
            (n.EventCode!.StartsWith("CONTRACT_") && n.EventKey == n.EventCode + ":HOP_DONG:" + n.TargetId ||
             n.EventCode.StartsWith("PAYMENT_") && payments.Any(p => p.MaHopDong == n.TargetId && p.PhuongThuc == "TIEN_MAT" &&
                 n.EventKey == "payment:" + p.MaThanhToan + ":" + n.EventCode.Substring(8)) ||
             n.EventCode.StartsWith("EXTENSION_") && appendices.Any(p => p.MaHopDong == n.TargetId &&
                 n.EventKey == "extension:" + p.MaPhuLuc + ":" + n.EventCode.Substring(10))));
        return deliveries.Where(d => d.DeviceTokenId == DeviceRegistrationId && allowed.Any(n => n.MaThongBao == d.MaThongBao));
    }
    private IQueryable<NotificationDelivery> Deliveries(RentalCameraContext db) =>
        Deliveries(db.NotificationDelivery, db.ThongBao, db.HopDong, db.ThanhToan, db.PhuLuc);

    public bool DeviceMatches(FcmDeviceToken? device) => device is not null && device.Id == DeviceRegistrationId &&
        device.MaTaiKhoan == AccountId && device.TokenHash == DeviceTokenHash && device.IsActive && device.Platform == "ANDROID";
    public static bool MayLease(NotificationDelivery d, DateTime now) =>
        d.State == "PENDING" && d.Attempts < 8 && d.NextAttemptUtc <= now && d.LastErrorCode != "TRANSPORT_UNCERTAIN";

    // Preserve the existing product retry ceiling/backoff for an explicit transient
    // FCM rejection. Uncertain transport results and durable SENDING are never replayed.
    public static void RecordFailure(NotificationDelivery d, DateTime now, string? firebaseCode, bool uncertain, TimeSpan? retryAfter = null)
    {
        d.LastErrorCode = uncertain ? "TRANSPORT_UNCERTAIN" : firebaseCode ?? "FIREBASE_ERROR";
        d.State = !uncertain && firebaseCode == "Unregistered" ? "INVALID_DEVICE" :
            !uncertain && (firebaseCode is "Unavailable" or "Internal" or "QuotaExceeded") && d.Attempts < 8 ? "PENDING" : "FAILED";
        if (d.State == "PENDING") {
            var delay = Math.Max(firebaseCode == "QuotaExceeded" ? 60 : 1, Math.Min(3600, 15 * Math.Pow(2, d.Attempts)));
            if (retryAfter.HasValue) delay = Math.Max(delay, retryAfter.Value.TotalSeconds);
            d.NextAttemptUtc = now.AddSeconds(delay);
        }
        d.LeaseUntilUtc = null;
    }

    public static async Task<DateTime> ServerUtcAsync(RentalCameraContext db, CancellationToken ct) =>
        DateTime.SpecifyKind(await db.Database.SqlQueryRaw<DateTime>("SELECT SYSUTCDATETIME() AS [Value]").SingleAsync(ct), DateTimeKind.Utc);

    public async Task<bool> DrainOneAsync(RentalCameraContext db, Func<FcmDeviceToken, ThongBao, CancellationToken, Task> send, CancellationToken ct)
    {
        if (Halted) return false;
        LastProblem = null;
        try
        {
            var correctDb = await db.Database.SqlQueryRaw<int>("SELECT CASE WHEN DB_NAME() COLLATE Latin1_General_100_BIN2=N'RentalCameraDb20_Test' THEN 1 ELSE 0 END AS [Value]").SingleAsync(ct);
            if (correctDb != 1) { Halted = true; HaltReason = "WRONG_DATABASE"; return false; }
            NotificationDelivery? delivery;
            await using (var tx = await db.Database.BeginTransactionAsync(ct))
            {
                await TransactionLock.AcquireAsync(db, "fcm-test-delivery:" + DeviceRegistrationId, ct);
                var now = await ServerUtcAsync(db, ct);
                if (now < CutoverUtc) return false;
                // A logout/rebind pauses this recipient. Logging back into the same
                // confirmed registration resumes naturally, without reopening any session.
                if (!DeviceMatches(await db.FcmDeviceToken.AsNoTracking().SingleOrDefaultAsync(d => d.Id == DeviceRegistrationId, ct))) return false;
                delivery = await Deliveries(db).Where(d => d.State == "PENDING" && d.Attempts < 8 &&
                        d.NextAttemptUtc <= now && d.LastErrorCode != "TRANSPORT_UNCERTAIN")
                    .OrderBy(d => d.NextAttemptUtc).ThenBy(d => d.Id).FirstOrDefaultAsync(ct);
                if (delivery is null) return false;
                delivery.State = "SENDING"; delivery.Attempts++; delivery.LeaseUntilUtc = now.AddMinutes(2);
                await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            }
            await using var finalGuard = await db.Database.BeginTransactionAsync(ct);
            await TransactionLock.AcquireAsync(db, "fcm:" + DeviceTokenHash, ct);
            var device = await db.FcmDeviceToken.SingleOrDefaultAsync(d => d.Id == DeviceRegistrationId, ct);
            if (!DeviceMatches(device) || !await Deliveries(db).AnyAsync(d => d.Id == delivery.Id, ct))
            {
                delivery.State = "SKIPPED"; delivery.LastErrorCode = "TEST_RECIPIENT_CHANGED";
            }
            else
            {
                var notice = await db.ThongBao.AsNoTracking().SingleAsync(n => n.MaThongBao == delivery.MaThongBao, ct);
                try
                {
                    using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                    timeout.CancelAfter(TimeSpan.FromSeconds(8));
                    await send(device!, notice, timeout.Token);
                    delivery.State = "SENT"; delivery.LastErrorCode = null;
                }
                catch (FirebaseMessagingException ex)
                {
                    var now = await ServerUtcAsync(db, ct);
                    var header = ex.HttpResponse?.Headers.RetryAfter;
                    var retryAfter = header?.Delta;
                    if (header?.Date is DateTimeOffset date) retryAfter = date.UtcDateTime - now;
                    RecordFailure(delivery, now, ex.MessagingErrorCode?.ToString(), false, retryAfter);
                    if (delivery.State == "INVALID_DEVICE") { device!.IsActive = false; device.UpdatedAt = DateTime.UtcNow; }
                }
                catch (Exception) when (!ct.IsCancellationRequested)
                {
                    RecordFailure(delivery, await ServerUtcAsync(db, ct), null, true);
                }
            }
            delivery.LeaseUntilUtc = null;
            await db.SaveChangesAsync(ct); await finalGuard.CommitAsync(ct);
            return true;
        }
        catch (Exception) when (!ct.IsCancellationRequested)
        {
            // An ambiguous committed lease remains SENDING and cannot be recovered
            // by this policy. Other future events can continue on the next poll.
            LastProblem = "DATABASE_OR_LEASE_UNCERTAIN";
            return false;
        }
    }
}
