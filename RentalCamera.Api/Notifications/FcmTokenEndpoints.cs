using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

public static class FcmTokenEndpoints
{
    public static void MapFcmTokenEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/thong-bao/fcm-token")
            .RequireAuthorization();

        group.MapPost("", async (
            RegisterFcmTokenRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var fid = request.Fid?.Trim();

            if (string.IsNullOrWhiteSpace(fid) || fid.Length > 2048)
            {
                return Results.BadRequest(new
                {
                    message = "Firebase Installation ID không hợp lệ."
                });
            }

            var platform = request.Platform?.Trim().ToUpperInvariant();

            if (platform is not ("ANDROID" or "IOS"))
            {
                return Results.BadRequest(new
                {
                    message = "Platform phải là ANDROID hoặc IOS."
                });
            }

            var deviceId = string.IsNullOrWhiteSpace(request.DeviceId)
                ? null
                : request.DeviceId.Trim();

            if (deviceId?.Length > 200)
            {
                return Results.BadRequest(new
                {
                    message = "DeviceId không được vượt quá 200 ký tự."
                });
            }

            var accountId =
                principal.FindFirstValue(ClaimTypes.NameIdentifier)!;

            var fidHash = Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(fid)));

            var now = DateTime.UtcNow;

            await using var tx = await db.Database.BeginTransactionAsync(ct);
            await TransactionLock.AcquireAsync(db, "fcm:" + fidHash, ct);

            var deviceToken = await db.FcmDeviceToken
                .SingleOrDefaultAsync(x => x.TokenHash == fidHash, ct);

            if (deviceToken is null)
            {
                deviceToken = new FcmDeviceToken
                {
                    Id = Guid.NewGuid().ToString(),
                    MaTaiKhoan = accountId,

                    // Cột Token hiện lưu Firebase Installation ID.
                    Token = fid,
                    TokenHash = fidHash,

                    Platform = platform,
                    DeviceId = deviceId,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                };

                db.FcmDeviceToken.Add(deviceToken);
            }
            else
            {
                deviceToken.MaTaiKhoan = accountId;
                deviceToken.Token = fid;
                deviceToken.Platform = platform;
                deviceToken.DeviceId = deviceId;
                deviceToken.IsActive = true;
                deviceToken.UpdatedAt = now;
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            return Results.Ok(new
            {
                id = deviceToken.Id,
                platform = deviceToken.Platform,
                isActive = deviceToken.IsActive
            });
        });

        group.MapDelete("/{id}", async (
            string id,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var accountId =
                principal.FindFirstValue(ClaimTypes.NameIdentifier)!;

            var hash = await db.FcmDeviceToken.AsNoTracking()
                .Where(x => x.Id == id && x.MaTaiKhoan == accountId && x.IsActive)
                .Select(x => x.TokenHash).SingleOrDefaultAsync(ct);
            if (hash is null) return Results.NotFound();
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            await TransactionLock.AcquireAsync(db, "fcm:" + hash, ct);
            // Re-read after the same lock used by registration and scoped transport.
            var deviceToken = await db.FcmDeviceToken
                .SingleOrDefaultAsync(
                    x => x.Id == id &&
                         x.MaTaiKhoan == accountId &&
                         x.IsActive,
                    ct);

            if (deviceToken is null)
            {
                return Results.NotFound();
            }

            deviceToken.IsActive = false;
            deviceToken.UpdatedAt = DateTime.UtcNow;

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.NoContent();
        });
    }

    private sealed record RegisterFcmTokenRequest(
        string Fid,
        string Platform,
        string? DeviceId);
}
