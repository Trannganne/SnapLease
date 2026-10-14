using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
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

            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

            var payment = await db.ThanhToan
                .FromSqlInterpolated($"SELECT * FROM dbo.ThanhToan WITH (UPDLOCK, ROWLOCK) WHERE MaThanhToan = {id}")
                .SingleOrDefaultAsync(ct);

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

            // 1. Kiểm tra xem có attempt nào đang CHO_THANH_TOAN và còn hạn không (chống double tap)
            var activeAttempt = await db.YeuCauThanhToanVnpay
                .Where(x => x.MaThanhToan == id && x.TrangThai == "CHO_THANH_TOAN")
                .OrderByDescending(x => x.ThoiGianTao)
                .FirstOrDefaultAsync(ct);

            if (activeAttempt is not null && activeAttempt.ThoiGianHetHan > DateTime.UtcNow)
            {
                await transaction.CommitAsync(ct);
                return Results.Ok(ToPaymentResponse(payment, activeAttempt.DuongDanThanhToan, true));
            }

            // Chặn retry không an toàn: Attempt đã hết hạn nhưng kết quả chưa được đối soát (chưa xác định)
            if (activeAttempt is not null && activeAttempt.ThoiGianHetHan <= DateTime.UtcNow)
            {
                await transaction.CommitAsync(ct);
                return Results.Conflict(new
                {
                    loi = "Yêu cầu thanh toán VNPAY trước đó đã hết hạn nhưng kết quả chưa được xác định. Cần thực hiện đối soát trạng thái trước khi tạo yêu cầu mới.",
                    canDoiSoat = true,
                    maThanhToan = payment.MaThanhToan,
                    maThamChieu = activeAttempt.MaThamChieu
                });
            }

            // Fallback kiểm tra attempt cũ lưu trực tiếp ở ThanhToan (backward compatibility)
            if (activeAttempt is null &&
                !string.IsNullOrWhiteSpace(payment.DuongDanThanhToan) &&
                payment.ThoiGianHetHan is not null)
            {
                if (payment.ThoiGianHetHan > DateTime.UtcNow)
                {
                    await transaction.CommitAsync(ct);
                    return Results.Ok(ToPaymentResponse(payment, payment.DuongDanThanhToan, true));
                }

                await transaction.CommitAsync(ct);
                return Results.Conflict(new
                {
                    loi = "Yêu cầu thanh toán VNPAY trước đó đã hết hạn nhưng kết quả chưa được xác định. Cần thực hiện đối soát trạng thái trước khi tạo yêu cầu mới.",
                    canDoiSoat = true,
                    maThanhToan = payment.MaThanhToan,
                    maThamChieu = payment.MaThamChieu
                });
            }

            // Bảo toàn tham chiếu cũ: Nếu payment.MaThamChieu đã có giá trị mà chưa có trong YeuCauThanhToanVnpay, snapshot lại
            if (!string.IsNullOrWhiteSpace(payment.MaThamChieu))
            {
                var existingRef = await db.YeuCauThanhToanVnpay
                    .AnyAsync(x => x.MaThamChieu == payment.MaThamChieu, ct);
                if (!existingRef)
                {
                    db.YeuCauThanhToanVnpay.Add(new YeuCauThanhToanVnpay
                    {
                        MaYeuCau = Guid.NewGuid().ToString("N"),
                        MaThanhToan = payment.MaThanhToan,
                        MaThamChieu = payment.MaThamChieu,
                        SoTien = payment.SoTien,
                        TienTe = "VND",
                        DuongDanThanhToan = payment.DuongDanThanhToan ?? "",
                        ThoiGianHetHan = payment.ThoiGianHetHan ?? DateTime.UtcNow,
                        TrangThai = payment.TrangThai == "THANH_CONG" ? "THANH_CONG" : "HET_HAN",
                        LaThuThua = false,
                        MaGiaoDich = payment.MaGiaoDich,
                        MaNganHang = payment.MaNganHang,
                        LoaiThe = payment.LoaiThe,
                        MaPhanHoi = payment.MaPhanHoi,
                        ThoiGianTao = payment.ThoiGianCapNhat ?? DateTime.UtcNow,
                        ThoiGianCapNhat = DateTime.UtcNow
                    });
                }
            }

            // Đánh dấu attempt cũ đã hết hạn (chỉ khi không còn attempt nào chờ đối soát)
            var expiredAttempts = await db.YeuCauThanhToanVnpay
                .Where(x => x.MaThanhToan == id && x.TrangThai == "CHO_THANH_TOAN" && x.ThoiGianHetHan <= DateTime.UtcNow)
                .ToListAsync(ct);
            foreach (var exp in expiredAttempts)
            {
                exp.TrangThai = "HET_HAN";
                exp.ThoiGianCapNhat = DateTime.UtcNow;
            }

            // 2. Tạo mã tham chiếu duy nhất tuân thủ giới hạn ký tự VNPAY (< 34 ký tự)
            var prefix = payment.MaThanhToan.Length > 12 ? payment.MaThanhToan[..12] : payment.MaThanhToan;
            var timestamp = DateTimeOffset.UtcNow.ToString("yyMMddHHmmss");
            var randomSuffix = RandomNumberGenerator.GetHexString(4).ToUpperInvariant();
            var transactionReference = $"{prefix}_{timestamp}_{randomSuffix}";

            var orderInfo = $"THANH TOAN {payment.LoaiThanhToan} {payment.MaThanhToan}";
            var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
            var link = vnpay.CreatePaymentUrl(transactionReference, payment.SoTien, orderInfo, clientIp);

            var newAttempt = new YeuCauThanhToanVnpay
            {
                MaYeuCau = Guid.NewGuid().ToString("N"),
                MaThanhToan = payment.MaThanhToan,
                MaThamChieu = link.TransactionReference,
                SoTien = payment.SoTien,
                TienTe = "VND",
                DuongDanThanhToan = link.PaymentUrl,
                ThoiGianHetHan = link.ExpiresAtUtc,
                TrangThai = "CHO_THANH_TOAN",
                LaThuThua = false,
                ThoiGianTao = DateTime.UtcNow
            };
            db.YeuCauThanhToanVnpay.Add(newAttempt);

            // Cập nhật ThanhToan để bảo toàn khả năng tương thích ngược
            payment.NhaCungCap = "VNPAY";
            payment.MaThamChieu = link.TransactionReference;
            payment.DuongDanThanhToan = link.PaymentUrl;
            payment.ThoiGianHetHan = link.ExpiresAtUtc;
            payment.ThoiGianCapNhat = DateTime.UtcNow;

            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return Results.Ok(ToPaymentResponse(payment, link.PaymentUrl, false));
        }).RequireAuthorization();

        app.MapPost("/api/thanh-toan/{id}/vnpay/doi-soat", async (
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

            // 1. Kiểm tra quyền truy cập và dữ liệu sơ bộ (không giữ lock DB)
            var initialPayment = await db.ThanhToan.AsNoTracking()
                .SingleOrDefaultAsync(x => x.MaThanhToan == id, ct);
            if (initialPayment is null) return Results.NotFound();

            if (!await ApiAccess.CanAccessContractAsync(initialPayment.MaHopDong, principal, db, ct))
                return Results.Forbid();

            if (initialPayment.TrangThai == "THANH_CONG")
            {
                return Results.Ok(new
                {
                    thanhCong = true,
                    trangThai = "THANH_CONG",
                    maThanhToan = initialPayment.MaThanhToan,
                    maGiaoDich = initialPayment.MaGiaoDich,
                    thongBao = "Giao dịch đã được xác nhận thanh toán thành công trước đó."
                });
            }

            if (initialPayment.NhaCungCap != "VNPAY" || initialPayment.PhuongThuc != "VI_DIEN_TU" || initialPayment.LoaiThanhToan == "HOAN_COC")
                return Results.BadRequest(new { loi = "Giao dịch không thuộc luồng thu tiền VNPAY." });

            var latestAttempt = await db.YeuCauThanhToanVnpay.AsNoTracking()
                .Where(x => x.MaThanhToan == id)
                .OrderByDescending(x => x.ThoiGianTao)
                .FirstOrDefaultAsync(ct);

            var txnRef = latestAttempt?.MaThamChieu ?? initialPayment.MaThamChieu;
            if (string.IsNullOrWhiteSpace(txnRef))
            {
                return Results.BadRequest(new { loi = "Không tìm thấy mã tham chiếu VNPAY để đối soát." });
            }

            var txnDate = latestAttempt?.ThoiGianTao ?? initialPayment.ThoiGianCapNhat ?? DateTime.UtcNow;
            var issuedUrl = latestAttempt?.DuongDanThanhToan ?? initialPayment.DuongDanThanhToan;
            if (Uri.TryCreate(issuedUrl, UriKind.Absolute, out var issuedUri))
            {
                var issuedQuery = QueryHelpers.ParseQuery(issuedUri.Query);
                if (DateTimeOffset.TryParseExact(issuedQuery["vnp_CreateDate"].ToString() + "+07:00",
                    "yyyyMMddHHmmsszzz", System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out var issuedAt))
                    txnDate = issuedAt.UtcDateTime;
            }
            var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";

            // 2. Gọi đối soát QueryDR sang VNPAY - TUYỆT ĐỐI KHÔNG GIỮ TRANSACTION DB
            var queryResult = await vnpay.QueryTransactionAsync(txnRef, txnDate, clientIp, ct);

            // 3. Sau khi QueryDR trả về, mở transaction Serializable để đối chiếu và xử lý đồng thời
            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

            var payment = await db.ThanhToan
                .FromSqlInterpolated($"SELECT * FROM dbo.ThanhToan WITH (UPDLOCK, ROWLOCK) WHERE MaThanhToan = {id}")
                .SingleOrDefaultAsync(ct);

            if (payment is null)
            {
                await transaction.RollbackAsync(ct);
                return Results.NotFound();
            }

            // Nếu trong lúc gọi HTTP, IPN đồng thời đã cập nhật thành công:
            if (payment.TrangThai == "THANH_CONG")
            {
                await transaction.CommitAsync(ct);
                return Results.Ok(new
                {
                    thanhCong = true,
                    trangThai = "THANH_CONG",
                    maThanhToan = payment.MaThanhToan,
                    maGiaoDich = payment.MaGiaoDich,
                    thongBao = "Giao dịch đã được xác nhận thành công."
                });
            }

            var attempt = await db.YeuCauThanhToanVnpay
                .Where(x => x.MaThamChieu == txnRef)
                .SingleOrDefaultAsync(ct);

            // Phân tích kết quả QueryDR
            if (queryResult.Success) // ResponseCode == "00" && TransactionStatus == "00"
            {
                var callbackData = new VnpayCallbackData(
                    txnRef,
                    queryResult.AmountTimes100!.Value,
                    queryResult.ResponseCode!,
                    queryResult.TransactionStatus!,
                    queryResult.TransactionNumber,
                    queryResult.BankCode,
                    null,
                    queryResult.PaidAt);

                var (rspCode, message) = await ProcessPaymentCallbackAsync(db, attempt, payment, callbackData, ct);
                if (rspCode != "00" && rspCode != "02")
                {
                    await transaction.RollbackAsync(ct);
                    return Results.Conflict(new { thanhCong = false, trangThai = payment.TrangThai, loi = message });
                }
                await transaction.CommitAsync(ct);

                return Results.Ok(new
                {
                    thanhCong = payment.TrangThai == "THANH_CONG",
                    trangThai = payment.TrangThai,
                    maThanhToan = payment.MaThanhToan,
                    maGiaoDich = payment.MaGiaoDich,
                    maPhanHoi = queryResult.ResponseCode,
                    thongBao = "Đối soát thành công: Giao dịch đã được cập nhật sang THANH_CONG."
                });
            }

            // Kết quả xác định là thất bại từ VNPAY (mã 02: thất bại, mã 07: nghi ngờ gian lận)
            if (queryResult.ErrorDetail is null && queryResult.ResponseCode == "00" && queryResult.TransactionStatus is "02" or "07")
            {
                if (attempt is not null)
                {
                    attempt.TrangThai = "THAT_BAI";
                    attempt.MaPhanHoi = queryResult.ResponseCode;
                    attempt.ThoiGianCapNhat = DateTime.UtcNow;
                }

                if (payment.TrangThai != "THANH_CONG")
                {
                    payment.ThoiGianCapNhat = DateTime.UtcNow;
                }

                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);

                return Results.Ok(new
                {
                    thanhCong = false,
                    trangThai = "THAT_BAI",
                    maThanhToan = payment.MaThanhToan,
                    maPhanHoi = queryResult.ResponseCode,
                    trangThaiGiaoDichVnpay = queryResult.TransactionStatus,
                    thongBao = "VNPAY xác nhận giao dịch thất bại. Bây giờ bạn có thể tạo yêu cầu thanh toán lại."
                });
            }

            // Các trường hợp chưa rõ (timeout, lỗi kết nối, sai chữ ký, trạng thái đang xử lý 01/05 hoặc mã 91/99)
            await transaction.CommitAsync(ct);
            return Results.Conflict(new
            {
                thanhCong = false,
                chuaXacDinh = true,
                trangThai = payment.TrangThai,
                maThanhToan = payment.MaThanhToan,
                maThamChieu = txnRef,
                maPhanHoi = queryResult.ResponseCode,
                trangThaiGiaoDichVnpay = queryResult.TransactionStatus,
                loi = queryResult.Message ?? queryResult.ErrorDetail ?? "Chưa thể xác định kết quả giao dịch từ VNPAY.",
                chiTiet = queryResult.ErrorDetail,
                thongBao = "Kết quả đối soát chưa xác định. Hệ thống tiếp tục giữ trạng thái chờ và chưa cho phép tạo giao dịch mới."
            });
        }).RequireAuthorization().RequireRateLimiting("vnpay-query");

        app.MapGet("/api/thanh-toan/vnpay/ipn", async (
            HttpRequest request,
            RentalCameraContext db,
            VnpayService vnpay,
            CancellationToken ct) =>
        {
            if (!vnpay.IsConfigured)
                return Results.Ok(new { RspCode = "99", Message = "VNPAY is not configured" });
            if (!vnpay.ValidateMerchant(request.Query["vnp_TmnCode"].ToString()))
                return Results.Ok(new { RspCode = "99", Message = "Invalid merchant" });
            if (!vnpay.ValidateSignature(request.Query))
                return Results.Ok(new { RspCode = "97", Message = "Invalid signature" });
            if (!VnpayService.TryReadCallback(request.Query, out var callback) || callback is null)
                return Results.Ok(new { RspCode = "99", Message = "Invalid request" });

            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

            // 1. Tra cứu attempt theo MaThamChieu chính xác 1-1
            var attempt = await db.YeuCauThanhToanVnpay.SingleOrDefaultAsync(
                x => x.MaThamChieu == callback.TransactionReference, ct);

            ThanhToan? payment;
            if (attempt is not null)
            {
                payment = await db.ThanhToan
                    .FromSqlInterpolated($"SELECT * FROM dbo.ThanhToan WITH (UPDLOCK, ROWLOCK) WHERE MaThanhToan = {attempt.MaThanhToan}")
                    .SingleOrDefaultAsync(ct);
            }
            else
            {
                // Fallback tương thích ngược: Tìm giao dịch cũ lưu trực tiếp ở ThanhToan
                payment = await db.ThanhToan
                    .FromSqlInterpolated($"SELECT * FROM dbo.ThanhToan WITH (UPDLOCK, ROWLOCK) WHERE MaThamChieu = {callback.TransactionReference}")
                    .SingleOrDefaultAsync(ct);
            }

            if (payment is null)
                return Results.Ok(new { RspCode = "01", Message = "Order not found" });

            var (rspCode, message) = await ProcessPaymentCallbackAsync(db, attempt, payment, callback, ct);
            await transaction.CommitAsync(ct);

            return Results.Ok(new { RspCode = rspCode, Message = message });
        }).AllowAnonymous();

        app.MapGet("/api/thanh-toan/vnpay/return", async (
            HttpRequest request,
            RentalCameraContext db,
            VnpayService vnpay,
            CancellationToken ct) =>
        {
            if (!vnpay.IsConfigured)
                return Results.Problem("VNPAY Sandbox chưa được cấu hình.", statusCode: StatusCodes.Status503ServiceUnavailable);
            if (!vnpay.ValidateMerchant(request.Query["vnp_TmnCode"].ToString()))
                return Results.BadRequest(new { loi = "Mã đơn vị VNPAY không hợp lệ." });
            if (!vnpay.ValidateSignature(request.Query))
                return Results.BadRequest(new { loi = "Chữ ký VNPAY không hợp lệ." });
            if (!VnpayService.TryReadCallback(request.Query, out var callback) || callback is null)
                return Results.BadRequest(new { loi = "Kết quả VNPAY thiếu dữ liệu bắt buộc." });

            var attempt = await db.YeuCauThanhToanVnpay.AsNoTracking().SingleOrDefaultAsync(
                x => x.MaThamChieu == callback.TransactionReference, ct);

            ThanhToan? payment;
            if (attempt is not null)
            {
                payment = await db.ThanhToan.AsNoTracking().SingleOrDefaultAsync(
                    x => x.MaThanhToan == attempt.MaThanhToan, ct);
            }
            else
            {
                payment = await db.ThanhToan.AsNoTracking().SingleOrDefaultAsync(
                    x => x.MaThamChieu == callback.TransactionReference, ct);
            }

            if (payment is null) return Results.NotFound();

            if (vnpay.MobileCallbackUrl is { } mobileCallbackUrl)
            {
                var redirectUrl = QueryHelpers.AddQueryString(mobileCallbackUrl, new Dictionary<string, string?>
                {
                    ["maThanhToan"] = payment.MaThanhToan,
                    ["maHopDong"] = payment.MaHopDong,
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

    private static async Task<(string RspCode, string Message)> ProcessPaymentCallbackAsync(
        RentalCameraContext db,
        YeuCauThanhToanVnpay? attempt,
        ThanhToan payment,
        VnpayCallbackData callback,
        CancellationToken ct)
    {
        var expectedAmount = attempt?.SoTien ?? payment.SoTien;
        var callbackAmount = callback.AmountTimes100 / 100m;
        if (expectedAmount != callbackAmount)
        {
            return ("04", "Invalid amount");
        }

        // Idempotency: Giao dịch này đã được xác nhận thành công trước đó
        if (attempt?.TrangThai == "THANH_CONG" || (attempt is null && payment.TrangThai == "THANH_CONG"))
        {
            return ("02", "Order already confirmed");
        }

        var success = callback.ResponseCode == "00" && callback.TransactionStatus == "00";

        if (attempt is not null)
        {
            attempt.TrangThai = success ? "THANH_CONG" : "THAT_BAI";
            attempt.MaGiaoDich = callback.TransactionNumber;
            attempt.MaNganHang = callback.BankCode;
            attempt.LoaiThe = callback.CardType;
            attempt.MaPhanHoi = callback.ResponseCode;
            attempt.ThoiGianCapNhat = DateTime.UtcNow;
        }

        if (success)
        {
            if (payment.TrangThai == "THANH_CONG")
            {
                // THU THỪA: Khoản cọc cha đã được thanh toán bởi một attempt trước đó
                if (attempt is not null)
                {
                    attempt.LaThuThua = true;
                    attempt.GhiChu = $"CANH_BAO_THU_THUA: Khoan coc da duoc thanh toan truoc do. Giao dich {callback.TransactionNumber} thu thua.";
                }
            }
            else
            {
                // Cập nhật thành công lần đầu cho khoản cọc cha
                payment.TrangThai = "THANH_CONG";
                payment.MaGiaoDich = callback.TransactionNumber;
                payment.MaNganHang = callback.BankCode;
                payment.LoaiThe = callback.CardType;
                payment.MaPhanHoi = callback.ResponseCode;
                payment.ThoiGian = callback.PaidAt ?? DateTime.Now;
                payment.ThoiGianCapNhat = DateTime.UtcNow;
            }
        }
        else
        {
            // Attempt thất bại đến muộn KHÔNG được ghi đè khoản cọc đã thành công
            if (payment.TrangThai != "THANH_CONG")
            {
                payment.ThoiGianCapNhat = DateTime.UtcNow;
            }
        }

        await db.SaveChangesAsync(ct);
        return ("00", "Confirm Success");
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
