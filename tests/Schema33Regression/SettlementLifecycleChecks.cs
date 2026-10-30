using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Media;
using RentalCamera.Api.Reviews;
using RentalCamera.Api.Settlement;

internal static class SettlementLifecycleChecks
{
    public static async Task RunAsync()
    {
        var count = 0;
        void Check(bool condition, string name)
        {
            if (!condition) throw new Exception(name);
            count++;
        }
        var due = new DateTime(2030, 1, 4, 10, 0, 0);
        SettlementCharge[] charges = [new("rent", "TIEN_THUE", "Rent", 350_000),
            new("extension", "PHI_GIA_HAN", "Signed extension", 175_000)];
        SettlementSource[] sources = [new("OFFLINE_CASH", "TIEN_COC", "TIEN_MAT", 1_750_000, "THANH_CONG")];
        var doc = SettlementLedger.Create("OFFLINE_CONTRACT", "OFFLINE_STAFF", DateTime.UtcNow, due, charges, sources);
        Check(doc.TongNghiaVu == 525_000 && doc.CocKhauTru == 525_000 && doc.TongDuocHoanCoc == 1_225_000 && doc.ConPhaiThu == 0,
            "Actual cash deposit covers rent/extension; only the remainder is refundable");
        Check(SettlementLedger.Create("C", "S", DateTime.UtcNow, due, charges,
            [new("rent-receipt", "TIEN_THUE", "TIEN_MAT", 525_000, "THANH_CONG"), ..sources]).TongDuocHoanCoc == 1_750_000,
            "Prior rent payment is consumed before the deposit, without double charging");
        foreach (var example in new (string Name, DateTime Received, decimal LateFee)[] {
            ("early", due.AddDays(-1), 0), ("on time", due, 0),
            ("late below 24 hours", due.AddHours(23), 0),
            ("late exactly 24 hours", due.AddHours(24), 175_000),
            ("late 24 hours and 1 minute", due.AddHours(24).AddMinutes(1), 350_000) })
        {
            var lateFee = LateReturnService.Cost(due, example.Received, 175_000);
            var statement = SettlementLedger.Create("OFFLINE_CONTRACT", "OFFLINE_STAFF", DateTime.UtcNow, due,
                [..charges, new("late", "TRA_TRE", "Late return", lateFee)], sources);
            Check(lateFee == example.LateFee && statement.TongNghiaVu == 525_000 + example.LateFee &&
                statement.TongDuocHoanCoc == 1_225_000 - example.LateFee,
                $"{example.Name}: original rent and signed extension stay payable; only existing late rule changes the refund");
        }
        foreach (var invalid in new[] { sources[0] with { TrangThai = "CHO_THANH_TOAN" },
            sources[0] with { SoTien = -1 }, sources[0] with { SoTien = 1.001m } })
        {
            var rejected = false;
            try { SettlementLedger.Create("C", "S", DateTime.UtcNow, due, charges, [invalid]); }
            catch (InvalidOperationException) { rejected = true; }
            Check(rejected, "Pending, negative or over-precision receipts cannot fund a refund");
        }
        SettlementLedger.ValidateFullReturn(["D1", "D2"], ["D2", "D1"]);
        foreach (var invalid in new[] { new[] { "D1" }, new[] { "D1", "D1" }, new[] { "D1", "FOREIGN" } })
        {
            var rejected = false;
            try { SettlementLedger.ValidateFullReturn(["D1", "D2"], invalid); }
            catch (InvalidOperationException) { rejected = true; }
            Check(rejected, "Missing, duplicate and foreign return details are rejected");
        }
        Check(SettlementLedger.CanComplete(true, true, false, 0, 0, true, false, false, true, false, true),
            "Received refund acknowledgement permits completion without a review");
        Check(!SettlementLedger.CanComplete(true, true, false, 0, 0, false, false, false, true, true, true),
            "Staff recording a refund alone does not complete the contract");
        Check(!SettlementLedger.CanComplete(false, true, false, 0, 0, true, false, false, true, true, true) &&
            !SettlementLedger.CanComplete(true, false, false, 0, 0, true, false, false, true, true, true) &&
            !SettlementLedger.CanComplete(true, true, true, 0, 0, true, false, false, true, true, true),
            "Incomplete receipt/inspection or an exception blocks completion");
        Check(!SettlementLedger.CanComplete(true, true, false, 1, 0, true, false, false, true, true, true) &&
            !SettlementLedger.CanComplete(true, true, false, 0, 1, true, false, false, true, true, true) &&
            !SettlementLedger.CanComplete(true, true, false, 0, 0, true, true, false, true, true, true),
            "Unpaid debt, outstanding refund or pending payment blocks completion");
        Check(!SettlementLedger.CanComplete(true, true, false, 0, 0, true, false, false, true, false, false) &&
            SettlementLedger.CanComplete(true, true, false, 0, 0, true, false, false, true, true, false),
            "A no-refund settlement needs the owner's explicit agreement");
        var state = new SettlementWorkflow.State(new HopDong { MaHopDong = "OFFLINE_CONTRACT",
            TrangThai = "CHO_HOAN_TRA", PhienBanDieuKhoan = RentalPolicy.TermsVersion, DaDongYDieuKhoan = true },
            new BienBanNhanTra { ThucNhanLuc = due, KiemTraLucUtc = DateTime.UtcNow }, null,
            [new ChiTietHopDong { MaChiTietHopDong = "D1", NgayNhanThucTe = due }], [], [], [], []);
        Check(SettlementWorkflow.Blockers(state).Count == 0, "Inspected full return without pending obligations has no blocker");
        state.Appendices.Add(new PhuLuc { TrangThai = "CHO_KY" });
        Check(SettlementWorkflow.Blockers(state).Count > 0, "Unfinished renewal blocks final settlement");
        state.Appendices[0].TrangThai = "CHO_XAC_NHAN";
        Check(SettlementWorkflow.Blockers(state).Count > 0, "Early return cannot silently bypass a renewal awaiting approval");
        state.Appendices[0].TrangThai = "DA_HUY";
        Check(state.Appendices.Count == 1 && SettlementWorkflow.Blockers(state).Count == 0,
            "Explicitly canceled appendix remains in history without blocking settlement");
        state.Appendices.Clear();
        state.Payments.Add(new ThanhToan { TrangThai = "CHO_THANH_TOAN" });
        Check(SettlementWorkflow.Blockers(state).Count > 0, "Unknown prior payment cannot be hidden by settlement");
        state.Payments.Clear();
        state.Payments.Add(new ThanhToan { MaThanhToan = "OFFLINE_CASH", LoaiThanhToan = "TIEN_COC",
            TrangThai = "THANH_CONG", SoTien = 1_750_000 });
        state = state with { Final = new QuyetToanHopDong { Id = "OFFLINE_QT", CocDaThu = 1_750_000,
            HoanCocBanDau = 1_225_000 } };
        var refund = new ThanhToan { MaThanhToan = "OFFLINE_REFUND", MaQuyetToan = "OFFLINE_QT",
            LoaiThanhToan = "HOAN_COC", SoTien = 1_225_001, TrangThai = "CHO_THANH_TOAN" };
        state.Payments.Add(refund);
        Check(SettlementWorkflow.Refunded(state) == 0, "Requested refund is not evidence that money was returned");
        refund.TrangThai = "DA_HOAN";
        Check(SettlementWorkflow.FinancialMismatch(state), "Refund exceeding the finalized entitlement requires reconciliation");
        refund.TrangThai = "THAT_BAI";
        Check(SettlementWorkflow.Refunded(state) == 0, "Failed refund is never counted as returned money");
        Check(ReviewEndpoints.IsDetailUniqueConflict(2601, "duplicate 'UQ_DanhGia_MaChiTietHopDong'", ["UQ_DanhGia_MaChiTietHopDong"]) &&
            ReviewEndpoints.IsDetailUniqueConflict(2627, "duplicate 'UQ_DanhGia_MaChiTietHopDong'", ["UQ_DanhGia_MaChiTietHopDong"]),
            "Concurrent review duplicate maps to the existing detail-specific unique constraint");
        Check(!ReviewEndpoints.IsDetailUniqueConflict(2627, "duplicate 'PK_DanhGia'", ["UQ_DanhGia_MaChiTietHopDong"]) &&
            !ReviewEndpoints.IsDetailUniqueConflict(547, "foreign key 'UQ_DanhGia_MaChiTietHopDong'", ["UQ_DanhGia_MaChiTietHopDong"]),
            "Other DB conflicts cannot masquerade as an existing review");

        // Validate actual mapped review handlers. Invalid requests stop
        // before any database query; transport is disabled as an extra guard.
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            { Args = [], EnvironmentName = "OfflineSettlementChecks", ContentRootPath = AppContext.BaseDirectory });
        builder.Configuration.Sources.Clear();
        builder.Logging.ClearProviders();
        builder.Services.AddDbContextFactory<RentalCameraContext>(options => options.UseSqlServer(
            "Server=offline.invalid;Database=OfflineOnly;User ID=offline;Password=offline-only"));
        builder.Services.Configure<CloudinaryOptions>(builder.Configuration.GetSection("Cloudinary"));
        builder.Services.AddHttpClient<CloudinaryImageStorage>().ConfigurePrimaryHttpMessageHandler(() => new DenyExternalHttpHandler());
        await using var app = builder.Build();
        app.MapReviewEndpoints();
        var endpoint = ((IEndpointRouteBuilder)app).DataSources.SelectMany(s => s.Endpoints)
            .OfType<RouteEndpoint>().Single(e => e.RoutePattern.RawText == "/api/danh-gia" &&
                e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains("POST"));
        Check(endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>().Any(p => p.Policy == "Customer"),
            "Review creation retains the Customer authorization policy");
        foreach (var test in new (int Stars, string? Comment, string[] Highlights, int Status)[] {
            (0, null, Array.Empty<string>(), 400),
            (6, (string?)null, Array.Empty<string>(), 400),
            (1, (string?)null, Array.Empty<string>(), 400),
            (2, "   ", Array.Empty<string>(), 400),
            (5, new string('x', 501), Array.Empty<string>(), 400),
            (5, (string?)null, new[] { "UNSUPPORTED" }, 400) })
        {
            using var scope = app.Services.CreateScope();
            var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
            context.Features.Set<IHttpRequestBodyDetectionFeature>(new JsonBodyFeature());
            context.Request.Method = "POST"; context.Request.ContentType = "application/json";
            var bytes = Encoding.UTF8.GetBytes(SettlementJson.Write(new { maChiTietHopDong = "OFFLINE_DETAIL",
                soSao = test.Stars, nhanXet = test.Comment, diemNoiBat = test.Highlights }));
            await using var input = new MemoryStream(bytes); await using var output = new MemoryStream();
            context.Request.Body = input; context.Request.ContentLength = bytes.Length; context.Response.Body = output;
            await endpoint.RequestDelegate!(context);
            Check(context.Response.StatusCode == test.Status,
                $"Review validation: stars={test.Stars}, commentLength={test.Comment?.Length ?? 0}, highlights={test.Highlights.Length}, actual={context.Response.StatusCode}, expected={test.Status}");
        }
        Console.WriteLine($"PASS {count} settlement/return/review checks; no SQL connection, provider or runtime business request.");
    }

    private sealed class JsonBodyFeature : IHttpRequestBodyDetectionFeature
    {
        public bool CanHaveBody => true;
    }
}
