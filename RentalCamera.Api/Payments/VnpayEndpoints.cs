using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Payments;

public static class VnpayEndpoints
{
    public static void MapVnpayEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/thanh-toan/{id}/vnpay", async (
            string id,
            HttpContext httpContext,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            VnpayService vnpay,
            CancellationToken ct) =>
        {
            if (!vnpay.IsConfigured)
                return Results.Problem(
                    title: "VNPAY Sandbox chưa được cấu hình.",
                    detail: "Cần cấu hình Vnpay__Enabled, Vnpay__TmnCode, Vnpay__HashSecret và Vnpay__ReturnUrl.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var payment = await db.ThanhToan.SingleOrDefaultAsync(x => x.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            if (!await ApiAccess.CanAccessContractAsync(payment.MaHopDong, principal, db, ct))
                return Results.Forbid();
            if (payment.TrangThai != "CHO_THANH_TOAN")
                return Results.Conflict(new { loi = "Giao dịch không còn ở trạng thái chờ thanh toán." });
            if (payment.PhuongThuc != "VI_DIEN_TU")
                return Results.Conflict(new { loi = "Giao dịch phải có phương thức VI_DIEN_TU để thanh toán qua VNPAY." });
            if (payment.LoaiThanhToan == "HOAN_COC")
                return Results.Conflict(new { loi = "Hoàn cọc không được xử lý bằng luồng thu tiền VNPAY." });
            if (payment.NhaCungCap is not null && payment.NhaCungCap != "VNPAY")
                return Results.Conflict(new { loi = "Giao dịch đã được khởi tạo với nhà cung cấp khác." });

            if (!string.IsNullOrWhiteSpace(payment.DuongDanThanhToan) &&
                payment.ThoiGianHetHan is not null && payment.ThoiGianHetHan > DateTime.UtcNow)
            {
                return Results.Ok(ToPaymentResponse(payment, payment.DuongDanThanhToan, true));
            }
            if (!string.IsNullOrWhiteSpace(payment.MaThamChieu))
                return Results.Conflict(new { loi = "Yêu cầu VNPAY đã hết hạn; hãy tạo một giao dịch thanh toán mới." });

            var transactionReference = payment.MaThanhToan;
            var orderInfo = $"THANH TOAN {payment.LoaiThanhToan} {payment.MaThanhToan}";
            var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
            var link = vnpay.CreatePaymentUrl(transactionReference, payment.SoTien, orderInfo, clientIp);

            payment.NhaCungCap = "VNPAY";
            payment.MaThamChieu = link.TransactionReference;
            payment.DuongDanThanhToan = link.PaymentUrl;
            payment.ThoiGianHetHan = link.ExpiresAtUtc;
            payment.ThoiGianCapNhat = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            return Results.Ok(ToPaymentResponse(payment, link.PaymentUrl, false));
        }).RequireAuthorization();

        app.MapGet("/api/thanh-toan/vnpay/ipn", async (
            HttpRequest request,
            RentalCameraContext db,
            VnpayService vnpay,
            CancellationToken ct) =>
        {
            if (!vnpay.IsConfigured)
                return Results.Ok(new { RspCode = "99", Message = "VNPAY is not configured" });
            if (!vnpay.ValidateSignature(request.Query))
                return Results.Ok(new { RspCode = "97", Message = "Invalid signature" });
            if (!VnpayService.TryReadCallback(request.Query, out var callback) || callback is null)
                return Results.Ok(new { RspCode = "99", Message = "Invalid request" });

            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var payment = await db.ThanhToan.SingleOrDefaultAsync(
                x => x.MaThamChieu == callback.TransactionReference, ct);
            if (payment is null)
                return Results.Ok(new { RspCode = "01", Message = "Order not found" });

            var callbackAmount = callback.AmountTimes100 / 100m;
            if (payment.SoTien != callbackAmount)
                return Results.Ok(new { RspCode = "04", Message = "Invalid amount" });
            if (payment.TrangThai != "CHO_THANH_TOAN")
                return Results.Ok(new { RspCode = "02", Message = "Order already confirmed" });

            var success = callback.ResponseCode == "00" && callback.TransactionStatus == "00";
            payment.TrangThai = success ? "THANH_CONG" : "THAT_BAI";
            payment.MaGiaoDich = callback.TransactionNumber;
            payment.MaNganHang = callback.BankCode;
            payment.LoaiThe = callback.CardType;
            payment.MaPhanHoi = callback.ResponseCode;
            payment.ThoiGian = callback.PaidAt ?? DateTime.Now;
            payment.ThoiGianCapNhat = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);

            return Results.Ok(new { RspCode = "00", Message = "Confirm Success" });
        }).AllowAnonymous();

        app.MapGet("/api/thanh-toan/vnpay/return", async (
            HttpRequest request,
            RentalCameraContext db,
            VnpayService vnpay,
            CancellationToken ct) =>
        {
            if (!vnpay.IsConfigured)
                return Results.Problem("VNPAY Sandbox chưa được cấu hình.", statusCode: StatusCodes.Status503ServiceUnavailable);
            if (!vnpay.ValidateSignature(request.Query))
                return Results.BadRequest(new { loi = "Chữ ký VNPAY không hợp lệ." });
            if (!VnpayService.TryReadCallback(request.Query, out var callback) || callback is null)
                return Results.BadRequest(new { loi = "Kết quả VNPAY thiếu dữ liệu bắt buộc." });

            var payment = await db.ThanhToan.AsNoTracking().SingleOrDefaultAsync(
                x => x.MaThamChieu == callback.TransactionReference, ct);
            if (payment is null) return Results.NotFound();

            if (vnpay.MobileCallbackUrl is { } mobileCallbackUrl)
            {
                var redirectUrl = QueryHelpers.AddQueryString(mobileCallbackUrl, new Dictionary<string, string?>
                {
                    ["maThanhToan"] = payment.MaThanhToan,
                    ["trangThai"] = payment.TrangThai,
                    ["maPhanHoiVnpay"] = callback.ResponseCode,
                    ["callbackHopLe"] = "true"
                });
                return Results.Redirect(redirectUrl);
            }

            return Results.Ok(new
            {
                payment.MaThanhToan,
                payment.MaHopDong,
                payment.SoTien,
                payment.TrangThai,
                nhaCungCap = "VNPAY",
                callbackHopLe = true,
                maPhanHoiVnpay = callback.ResponseCode,
                thongBao = "Kết quả chính thức được cập nhật qua IPN; ứng dụng hãy đọc lại trạng thái giao dịch."
            });
        }).AllowAnonymous();
    }

    private static object ToPaymentResponse(ThanhToan payment, string paymentUrl, bool reused) => new
    {
        payment.MaThanhToan,
        payment.MaHopDong,
        payment.SoTien,
        payment.TrangThai,
        payment.NhaCungCap,
        payment.MaThamChieu,
        payment.ThoiGianHetHan,
        paymentUrl,
        reused,
        phuongThuc = "VNPAYQR"
    };
}
