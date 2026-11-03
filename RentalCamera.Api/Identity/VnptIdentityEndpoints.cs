using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Identity;

public static class VnptIdentityEndpoints
{
    public static void MapVnptIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/giay-to/{id}/vnpt-xac-minh", async (
            string id, VnptIdentityRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, IWebHostEnvironment environment,
            VnptEkycService service, CancellationToken ct) =>
        {
            if (service.UnavailableReason is { } unavailable)
                return Results.Json(new { code = "VNPT_EKYC_DISABLED", loi = unavailable }, statusCode: 503);
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var document = await db.GiayToTuyThan.SingleOrDefaultAsync(
                x => x.MaGiayTo == id && x.MaKhachThue == customerId, ct);
            if (document is null) return Results.NotFound(new { loi = "Không tìm thấy giấy tờ." });
            if (document.LoaiGiayTo != "CCCD" || string.IsNullOrWhiteSpace(document.MatSauUrl))
                return Results.BadRequest(new { loi = "VNPT eKYC hiện chỉ xử lý CCCD có đủ hai mặt." });
            if (document.KetQuaXacMinhTuDong is not null)
                return Results.Conflict(new { loi = "Giấy tờ đã có kết quả tự động; không gọi lại để tránh trừ quota." });

            VnptImage front;
            VnptImage back;
            VnptImage selfie;
            try
            {
                front = ReadStoredImage(environment.ContentRootPath, document.MatTruocUrl);
                back = ReadStoredImage(environment.ContentRootPath, document.MatSauUrl);
                selfie = ReadDataImage(request.SelfieBase64);
                VnptEkycService.ValidateImage(front, "Mặt trước CCCD");
                VnptEkycService.ValidateImage(back, "Mặt sau CCCD");
                VnptEkycService.ValidateImage(selfie, "Ảnh chân dung");
            }
            catch (VnptEkycException failure)
            {
                return Results.Json(new { code = failure.Code, loi = failure.Message }, statusCode: failure.Status);
            }
            catch (IOException)
            {
                return Results.BadRequest(new { loi = "Không đọc được ảnh giấy tờ đã lưu." });
            }

            document.NhaCungCapXacMinh = "VNPT_EKYC";
            document.MaThamChieuXacMinh = $"VNPT-{Guid.NewGuid():N}";
            document.KetQuaXacMinhTuDong = "CHO_XU_LY";
            document.XacMinhTuDongLucUtc = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            try
            {
                var result = await service.VerifyAsync(front, back, selfie, document.SoGiayTo, ct);
                document.MaThamChieuXacMinh = result.ReferenceId;
                document.KetQuaXacMinhTuDong = result.Outcome;
                document.DoTinCayOcr = result.OcrConfidence;
                document.DiemSoKhuonMat = result.FaceScore;
                document.DiemSoSong = null; // Liveness phải đến từ SDK VNPT, không suy đoán từ API ảnh tĩnh.
                document.XacMinhTuDongLucUtc = DateTime.UtcNow;
                await db.SaveChangesAsync(CancellationToken.None);
                return Results.Ok(new
                {
                    document.MaGiayTo,
                    document.KetQuaXacMinhTuDong,
                    document.DoTinCayOcr,
                    document.DiemSoKhuonMat,
                    liveness = "SDK_REQUIRED",
                    document.TrangThaiXacMinh
                });
            }
            catch (VnptEkycException failure)
            {
                document.KetQuaXacMinhTuDong = "LOI_NHA_CUNG_CAP";
                document.XacMinhTuDongLucUtc = DateTime.UtcNow;
                await db.SaveChangesAsync(CancellationToken.None);
                return Results.Json(new { code = failure.Code, loi = failure.Message }, statusCode: failure.Status);
            }
            catch (HttpRequestException)
            {
                document.KetQuaXacMinhTuDong = "LOI_NHA_CUNG_CAP";
                document.XacMinhTuDongLucUtc = DateTime.UtcNow;
                await db.SaveChangesAsync(CancellationToken.None);
                return Results.Json(new { code = "VNPT_NETWORK_ERROR", loi = "Không kết nối được VNPT eKYC." }, statusCode: 502);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                document.KetQuaXacMinhTuDong = "LOI_NHA_CUNG_CAP";
                document.XacMinhTuDongLucUtc = DateTime.UtcNow;
                await db.SaveChangesAsync(CancellationToken.None);
                return Results.Json(new { code = "VNPT_REQUEST_CANCELLED", loi = "Yêu cầu VNPT bị gián đoạn; không tự động gọi lại để tránh trừ quota." }, statusCode: 499);
            }
        }).RequireAuthorization("Customer")
          .WithMetadata(new RequestSizeLimitAttribute(8 * 1024 * 1024));
    }

    private static VnptImage ReadStoredImage(string contentRoot, string url)
    {
        const string prefix = "/api/giay-to/anh/";
        if (!url.StartsWith(prefix, StringComparison.Ordinal)) throw new IOException();
        var fileName = url[prefix.Length..];
        if (fileName != Path.GetFileName(fileName)) throw new IOException();
        var storage = Path.GetFullPath(Path.Combine(contentRoot, "Storage"));
        var path = Path.GetFullPath(Path.Combine(storage, fileName));
        if (!path.StartsWith(storage + Path.DirectorySeparatorChar, StringComparison.Ordinal) || !File.Exists(path))
            throw new IOException();
        return new VnptImage(File.ReadAllBytes(path), ContentTypeFromExtension(path));
    }

    private static VnptImage ReadDataImage(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new VnptEkycException("VNPT_SELFIE_REQUIRED", "Thiếu ảnh chân dung.", 400);
        var comma = value.IndexOf(',');
        if (comma <= 0 || !value[..comma].EndsWith(";base64", StringComparison.OrdinalIgnoreCase))
            throw new VnptEkycException("VNPT_IMAGE_FORMAT", "Ảnh chân dung phải là data URL Base64.", 400);
        var mediaType = value[5..value[..comma].IndexOf(';')].ToLowerInvariant();
        byte[] bytes;
        try { bytes = Convert.FromBase64String(value[(comma + 1)..]); }
        catch (FormatException) { throw new VnptEkycException("VNPT_IMAGE_FORMAT", "Ảnh chân dung Base64 không hợp lệ.", 400); }
        return new VnptImage(bytes, mediaType);
    }

    private static string ContentTypeFromExtension(string path) => Path.GetExtension(path).ToLowerInvariant() switch
    {
        ".jpg" or ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        _ => "application/octet-stream"
    };
}

public sealed record VnptIdentityRequest(string SelfieBase64);
