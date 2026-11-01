using System.Buffers.Binary;
using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Mvc;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Notifications;

namespace RentalCamera.Api.Identity;

public static class IdentityEndpoints
{
    public static void MapIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/giay-to").RequireAuthorization();

        group.MapGet("/cua-toi", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.GiayToTuyThan.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTaiLen).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");

        group.MapGet("/anh/{fileName}", async (string fileName, ClaimsPrincipal principal, RentalCameraContext db, IWebHostEnvironment env, CancellationToken ct) =>
        {
            var storagePath = Path.Combine(env.ContentRootPath, "Storage");
            if (string.IsNullOrWhiteSpace(fileName) || fileName != Path.GetFileName(fileName) ||
                fileName.Contains('/') || fileName.Contains('\\')) return Results.NotFound();
            var path = Path.GetFullPath(Path.Combine(storagePath, fileName));
            if (!path.StartsWith(Path.GetFullPath(storagePath) + Path.DirectorySeparatorChar, StringComparison.Ordinal) || !File.Exists(path))
                return Results.NotFound();

            // Lấy MaGiayTo từ DB để kiểm tra quyền
            var relativeUrl = $"/api/giay-to/anh/{fileName}";
            var giayTo = await db.GiayToTuyThan.AsNoTracking().FirstOrDefaultAsync(
                x => x.MatTruocUrl == relativeUrl || x.MatSauUrl == relativeUrl || x.SelfieUrl == relativeUrl, ct);
            if (giayTo is null) return Results.NotFound();
            var role = principal.FindFirstValue(ClaimTypes.Role);
            if (role == "KHACH_HANG")
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                if (customerId == null || giayTo.MaKhachThue != customerId) return Results.Forbid();
            }
            else
            {
                if (role is not ("ADMIN" or "NHAN_VIEN")) return Results.Forbid();
                var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
                if (scope is null || (!scope.IsAdmin && !await db.ChiTietGioHang.AnyAsync(
                    c => c.GioHang.MaKhachThue == giayTo.MaKhachThue && c.MaCuaHang == scope.StoreId, ct)))
                    return Results.Forbid();
            }

            var contentType = Path.GetExtension(path).ToLowerInvariant() switch
            {
                ".png" => "image/png",
                ".webp" => "image/webp",
                _ => "image/jpeg"
            };
            return Results.File(path, contentType);
        }).RequireAuthorization();

        group.MapPost("", async (IdentityDocumentRequest request, ClaimsPrincipal principal, RentalCameraContext db, IWebHostEnvironment env, CancellationToken ct) =>
        {
            if (request.LoaiGiayTo is not ("CCCD" or "HO_CHIEU" or "GPLX") ||
                string.IsNullOrWhiteSpace(request.HoTen) || request.HoTen.Length > 150 ||
                string.IsNullOrWhiteSpace(request.SoGiayTo) || request.SoGiayTo.Trim().Length > 30 ||
                string.IsNullOrWhiteSpace(request.MatTruocUrl))
                return Results.BadRequest(new { loi = "Thông tin giấy tờ không hợp lệ." });
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (await db.GiayToTuyThan.AnyAsync(x => x.SoGiayTo == request.SoGiayTo.Trim() && x.MaKhachThue != customerId, ct))
                return Results.Conflict(new { loi = "Số giấy tờ đã được sử dụng bởi khách thuê khác." });
            if (await db.GiayToTuyThan.AnyAsync(x => x.SoGiayTo == request.SoGiayTo.Trim(), ct))
                return Results.Conflict(new { loi = "Giấy tờ đã được gửi. Vui lòng kiểm tra hồ sơ hiện có trước khi gửi lại." });
            
            var writtenFiles = new List<string>();
            var saved = false;
            // Existing URLs may only reuse this customer's own stored documents.
            var ownUrls = await db.GiayToTuyThan.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .Select(x => new { x.MatTruocUrl, x.MatSauUrl }).ToListAsync(ct);
            (string? Url, string? Error) SaveBase64Image(string data) {
                if (!data.StartsWith("data:image", StringComparison.Ordinal))
                    return ownUrls.Any(x => x.MatTruocUrl == data || x.MatSauUrl == data)
                        ? (data, null) : (null, "Ảnh phải được tải lên hoặc thuộc giấy tờ của bạn.");
                var parts = data.Split(',');
                if (parts.Length != 2 || !parts[0].EndsWith(";base64", StringComparison.Ordinal))
                    return (null, "Chuỗi ảnh Base64 không hợp lệ.");
                byte[] bytes;
                try {
                    bytes = Convert.FromBase64String(parts[1]);
                } catch {
                    return (null, "Chuỗi Base64 không hợp lệ.");
                }

                if (bytes.Length > 10 * 1024 * 1024) {
                    return (null, "Ảnh vượt quá dung lượng cho phép (10MB).");
                }

                var extension = GetVerifiedImageExtension(bytes);
                if (extension is null) {
                    return (null, "Tệp không phải là hình ảnh hợp lệ hoặc bị hỏng.");
                }

                var filename = $"{Guid.NewGuid()}{extension}";
                var storagePath = Path.Combine(env.ContentRootPath, "Storage");
                Directory.CreateDirectory(storagePath);
                var path = Path.Combine(storagePath, filename);
                File.WriteAllBytes(path, bytes);
                writtenFiles.Add(path);
                return ($"/api/giay-to/anh/{filename}", null);
            }

            try {
                var matTruoc = SaveBase64Image(request.MatTruocUrl.Trim());
                if (matTruoc.Error != null) return Results.BadRequest(new { loi = $"Mặt trước: {matTruoc.Error}" });
                
                (string? Url, string? Error) matSau = (null, null);
                if (request.MatSauUrl != null) {
                    matSau = SaveBase64Image(request.MatSauUrl.Trim());
                    if (matSau.Error != null) return Results.BadRequest(new { loi = $"Mặt sau: {matSau.Error}" });
                }

                var entity = new GiayToTuyThan
                {
                    MaGiayTo = ApiAccess.NewId("GT"), MaKhachThue = customerId,
                    LoaiGiayTo = request.LoaiGiayTo, SoGiayTo = request.SoGiayTo.Trim(),
                    MatTruocUrl = matTruoc.Url!, 
                    MatSauUrl = matSau.Url,
                    NgayTaiLen = DateTime.Now, TrangThaiXacMinh = "CHO_XAC_MINH"
                };
                var customer = await db.KhachThue.SingleAsync(x => x.MaKhachThue == customerId, ct);
                customer.HoTen = request.HoTen.Trim();
                db.GiayToTuyThan.Add(entity);
                await db.SaveChangesAsync(ct);
                saved = true;
                return Results.Created($"/api/giay-to/{entity.MaGiayTo}", entity);
            } finally {
                foreach (var file in saved ? Enumerable.Empty<string>() : writtenFiles) {
                    if (File.Exists(file)) File.Delete(file);
                }
            }
        }).RequireAuthorization("Customer");

        group.MapPost("/{id}/ekyc", async (
            string id, EkycRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, IWebHostEnvironment env,
            [FromServices] IEkycProvider provider, IOptions<EkycOptions> ekycOptions,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var document = await db.GiayToTuyThan.SingleOrDefaultAsync(
                x => x.MaGiayTo == id && x.MaKhachThue == customerId, ct);
            if (document is null) return Results.NotFound(new { loi = "Không tìm thấy giấy tờ." });
            if (document.TrangThaiXacMinh != "CHO_XAC_MINH")
                return Results.Conflict(new { loi = "Giấy tờ đã được nhân viên xử lý." });
            if (document.LoaiGiayTo != "CCCD" || string.IsNullOrWhiteSpace(document.MatSauUrl))
                return Results.BadRequest(new { loi = "eKYC hiện yêu cầu CCCD có đủ ảnh mặt trước và mặt sau." });
            if (document.EkycStatus == "DAT")
                return Results.Conflict(new { loi = "Hồ sơ đã đạt kiểm tra eKYC; vui lòng chờ nhân viên duyệt." });

            var options = ekycOptions.Value;
            var maximumBytes = Math.Clamp(options.MaximumImageMegabytes, 1, 20) * 1024 * 1024;
            var selfie = DecodeDataImage(request.SelfieBase64, maximumBytes);
            if (selfie.Error is not null)
                return Results.BadRequest(new { loi = $"Ảnh selfie: {selfie.Error}" });
            var front = ReadStoredImage(env, document.MatTruocUrl, maximumBytes);
            var back = ReadStoredImage(env, document.MatSauUrl!, maximumBytes);
            if (front.Image is null || back.Image is null)
                return Results.BadRequest(new { loi = "Ảnh CCCD phải là ảnh đã tải trực tiếp lên hệ thống." });

            EkycProviderResult providerResult;
            try
            {
                providerResult = await provider.VerifyAsync(new(
                    document.LoaiGiayTo, document.SoGiayTo,
                    front.Image, back.Image, selfie.Image!), ct);
            }
            catch (EkycUnavailableException ex)
            {
                return Results.Json(new { loi = ex.Message }, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
            catch (HttpRequestException)
            {
                return Results.Json(new { loi = "Không thể kết nối nhà cung cấp eKYC." }, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
            catch (TaskCanceledException) when (!ct.IsCancellationRequested)
            {
                return Results.Json(new { loi = "Nhà cung cấp eKYC phản hồi quá thời gian." }, statusCode: StatusCodes.Status503ServiceUnavailable);
            }

            var decision = EkycDecisionPolicy.Evaluate(providerResult, document.SoGiayTo, options);
            var storagePath = Path.Combine(env.ContentRootPath, "Storage");
            Directory.CreateDirectory(storagePath);
            var selfieFileName = $"{Guid.NewGuid()}{selfie.Extension}";
            var selfiePath = Path.Combine(storagePath, selfieFileName);
            await File.WriteAllBytesAsync(selfiePath, selfie.Image!.Bytes, ct);
            var previousSelfie = document.SelfieUrl;
            document.SelfieUrl = $"/api/giay-to/anh/{selfieFileName}";
            document.EkycProvider = provider.Name[..Math.Min(provider.Name.Length, 50)];
            document.EkycReferenceId = providerResult.ReferenceId[..Math.Min(providerResult.ReferenceId.Length, 100)];
            document.EkycStatus = decision.Status;
            document.OcrConfidence = NormalizeScore(providerResult.OcrConfidence);
            document.FaceMatchScore = NormalizeScore(providerResult.FaceMatchScore);
            document.LivenessScore = NormalizeScore(providerResult.LivenessScore);
            document.EkycProcessedAtUtc = DateTime.UtcNow;
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch
            {
                if (File.Exists(selfiePath)) File.Delete(selfiePath);
                throw;
            }
            DeleteStoredImageIfReplaced(env, previousSelfie, document.SelfieUrl);

            return Results.Ok(new
            {
                document.MaGiayTo,
                document.EkycStatus,
                document.OcrConfidence,
                document.FaceMatchScore,
                document.LivenessScore,
                document.EkycProcessedAtUtc,
                canNhanVienDuyet = decision.Passed,
                ghiChu = decision.Reason
            });
        }).RequireAuthorization("Customer").RequireRateLimiting("ekyc");

        group.MapGet("/cho-xac-minh", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.GiayToTuyThan.AsNoTracking().Where(x => x.TrangThaiXacMinh == "CHO_XAC_MINH");
            if (!scope.IsAdmin)
                query = query.Where(x => db.ChiTietGioHang.Any(c => c.GioHang.MaKhachThue == x.MaKhachThue && c.MaCuaHang == scope.StoreId));
            var data = await query.OrderBy(x => x.NgayTaiLen)
                .Join(db.KhachThue, g => g.MaKhachThue, k => k.MaKhachThue, (g, k) => new
                {
                    g.MaGiayTo, g.MaKhachThue, k.HoTen, g.LoaiGiayTo, g.SoGiayTo,
                    g.MatTruocUrl, g.MatSauUrl, g.SelfieUrl, g.NgayTaiLen,
                    g.EkycProvider, g.EkycReferenceId, g.EkycStatus,
                    g.OcrConfidence, g.FaceMatchScore, g.LivenessScore, g.EkycProcessedAtUtc
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        group.MapPut("/{id}/xac-minh", async (
            string id, VerifyIdentityRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, FirebaseNotificationSender notificationSender,
            CancellationToken ct) =>
        {
            if (request.KetQua is not ("HOP_LE" or "TU_CHOI")) return Results.BadRequest();
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var document = await db.GiayToTuyThan.SingleOrDefaultAsync(x => x.MaGiayTo == id, ct);
            if (document is null) return Results.NotFound();
            if (!scope.IsAdmin && !await db.ChiTietGioHang.AnyAsync(
                c => c.GioHang.MaKhachThue == document.MaKhachThue && c.MaCuaHang == scope.StoreId, ct))
                return Results.Forbid();
            if (document.TrangThaiXacMinh != "CHO_XAC_MINH")
                return Results.Conflict(new { loi = "Giấy tờ đã được xử lý." });
            document.TrangThaiXacMinh = request.KetQua;
            document.GhiChu = request.GhiChu?.Trim();
            var customer = await db.KhachThue.SingleAsync(x => x.MaKhachThue == document.MaKhachThue, ct);
            if (request.KetQua == "HOP_LE" && document.LoaiGiayTo == "CCCD")
            {
                var cccd = document.SoGiayTo.Trim();
                if (await db.KhachThue.AnyAsync(x => x.CCCD == cccd && x.MaKhachThue != customer.MaKhachThue, ct))
                    return Results.Conflict(new { loi = "CCCD đã được sử dụng bởi khách thuê khác." });
                customer.CCCD = cccd;
            }
            const string notificationTitle = "Kết quả xác minh giấy tờ";
            var notificationBody = request.KetQua == "HOP_LE"
                ? "Giấy tờ của bạn đã được xác minh."
                : $"Giấy tờ bị từ chối. {request.GhiChu}";
            ApiAccess.AddNotification(
                db, customer.MaTaiKhoan, "XAC_MINH_GIAY_TO", notificationTitle, notificationBody,
                eventCode: "IDENTITY_VERIFICATION_RESULT", targetType: "GIAY_TO_TUY_THAN",
                targetId: document.MaGiayTo);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
            {
                return Results.Conflict(new { loi = "CCCD đã được sử dụng bởi khách thuê khác." });
            }
            return Results.Ok(new { document.MaGiayTo, document.TrangThaiXacMinh, document.GhiChu });
        }).RequireAuthorization("Staff");

        app.MapPost("/api/khach-thue/xac-nhan-danh-tinh", async (
            CustomerIdentityConfirmRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            if (string.IsNullOrWhiteSpace(request.MaGiayTo) ||
                string.IsNullOrWhiteSpace(request.Cccd) || string.IsNullOrWhiteSpace(request.HoTen) ||
                string.IsNullOrWhiteSpace(request.GioiTinh) || string.IsNullOrWhiteSpace(request.QuocTich) ||
                string.IsNullOrWhiteSpace(request.DiaChiThuongTru) || string.IsNullOrWhiteSpace(request.NoiCap))
                return Results.BadRequest(new { loi = "Thiếu thông tin xác nhận danh tính (cần đủ 8 trường bắt buộc)." });

            var doc = await db.GiayToTuyThan.SingleOrDefaultAsync(x => x.MaGiayTo == request.MaGiayTo && x.MaKhachThue == customerId, ct);
            if (doc is null) return Results.NotFound(new { loi = "Không tìm thấy giấy tờ." });

            if (string.IsNullOrWhiteSpace(doc.MatTruocUrl) || string.IsNullOrWhiteSpace(doc.MatSauUrl))
                return Results.BadRequest(new { loi = "Giấy tờ chưa đủ 2 mặt ảnh thực tế." });

            if (doc.LoaiGiayTo != "CCCD" || doc.SoGiayTo.Trim() != request.Cccd.Trim())
                return Results.BadRequest(new { loi = "CCCD xác nhận không khớp giấy tờ đã tải lên." });
            if (request.Cccd.Trim().Length > 20 || request.HoTen.Trim().Length > 150 ||
                request.GioiTinh.Trim().Length > 10 || request.QuocTich.Trim().Length > 100 ||
                request.DiaChiThuongTru.Trim().Length > 500 || request.NoiCap.Trim().Length > 200 ||
                request.NgaySinh == default || request.NgayCap == default)
                return Results.BadRequest(new { loi = "Thông tin danh tính không hợp lệ." });

            var customer = await db.KhachThue.SingleAsync(x => x.MaKhachThue == customerId, ct);
            
            customer.CCCD = request.Cccd.Trim();
            customer.HoTen = request.HoTen.Trim();
            customer.NgaySinh = request.NgaySinh;
            customer.GioiTinh = request.GioiTinh.Trim();
            customer.QuocTich = request.QuocTich.Trim();
            customer.DiaChi = request.DiaChiThuongTru.Trim();
            customer.NgayCap = request.NgayCap;
            customer.NoiCap = request.NoiCap.Trim();
            
            customer.DaXacNhanThongTin = true;

            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
            {
                return Results.Conflict(new { loi = "CCCD này đã được đăng ký cho một tài khoản khác trong hệ thống." });
            }

            return Results.Ok(new { success = true, loi = "" });
        }).RequireAuthorization("Customer");

        app.MapGet("/api/khach-thue/cua-toi", async (
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            var customer = await db.KhachThue.AsNoTracking().SingleOrDefaultAsync(x => x.MaKhachThue == customerId, ct);
            if (customer is null) return Results.NotFound(new { loi = "Không tìm thấy hồ sơ khách thuê." });

            return Results.Ok(new
            {
                hoTen = customer.HoTen,
                soDienThoai = customer.SoDienThoai,
                email = customer.Email,
                cccd = customer.CCCD,
                diaChiThuongTru = customer.DiaChi,
                ngaySinh = customer.NgaySinh,
                gioiTinh = customer.GioiTinh,
                quocTich = customer.QuocTich,
                ngayCap = customer.NgayCap,
                noiCap = customer.NoiCap,
                daXacNhanThongTin = customer.DaXacNhanThongTin
            });
        }).RequireAuthorization("Customer");
    }

    private static string? GetVerifiedImageExtension(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8 &&
            bytes[^2] == 0xFF && bytes[^1] == 0xD9)
            return ".jpg";

        ReadOnlySpan<byte> pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        ReadOnlySpan<byte> pngEnd = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44];
        if (bytes.Length >= 20 && bytes[..8].SequenceEqual(pngSignature) &&
            bytes.Slice(bytes.Length - 12, 8).SequenceEqual(pngEnd))
            return ".png";

        if (bytes.Length >= 12 && bytes[..4].SequenceEqual("RIFF"u8) &&
            bytes.Slice(8, 4).SequenceEqual("WEBP"u8) &&
            BinaryPrimitives.ReadUInt32LittleEndian(bytes.Slice(4, 4)) + 8 == bytes.Length)
            return ".webp";

        return null;
    }

    private static (EkycImage? Image, string? Extension, string? Error) DecodeDataImage(string? data, int maximumBytes)
    {
        if (string.IsNullOrWhiteSpace(data) || !data.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
            return (null, null, "Cần gửi ảnh dạng data URI Base64.");
        var comma = data.IndexOf(',');
        if (comma < 0 || !data[..comma].EndsWith(";base64", StringComparison.OrdinalIgnoreCase))
            return (null, null, "Chuỗi Base64 không hợp lệ.");
        byte[] bytes;
        try { bytes = Convert.FromBase64String(data[(comma + 1)..]); }
        catch (FormatException) { return (null, null, "Chuỗi Base64 không hợp lệ."); }
        if (bytes.Length == 0 || bytes.Length > maximumBytes)
            return (null, null, $"Dung lượng ảnh phải từ 1 byte đến {maximumBytes / 1024 / 1024}MB.");
        var extension = GetVerifiedImageExtension(bytes);
        if (extension is null) return (null, null, "Chỉ chấp nhận JPEG, PNG hoặc WebP hợp lệ.");
        return (new(bytes, ContentType(extension)), extension, null);
    }

    private static (EkycImage? Image, string? Error) ReadStoredImage(
        IWebHostEnvironment env, string relativeUrl, int maximumBytes)
    {
        const string prefix = "/api/giay-to/anh/";
        if (!relativeUrl.StartsWith(prefix, StringComparison.Ordinal)) return (null, "Ảnh không thuộc kho bảo mật.");
        var fileName = relativeUrl[prefix.Length..];
        if (fileName != Path.GetFileName(fileName)) return (null, "Tên ảnh không hợp lệ.");
        var storage = Path.GetFullPath(Path.Combine(env.ContentRootPath, "Storage"));
        var path = Path.GetFullPath(Path.Combine(storage, fileName));
        if (!path.StartsWith(storage + Path.DirectorySeparatorChar, StringComparison.Ordinal) || !File.Exists(path))
            return (null, "Không tìm thấy ảnh.");
        var info = new FileInfo(path);
        if (info.Length <= 0 || info.Length > maximumBytes) return (null, "Dung lượng ảnh không hợp lệ.");
        var bytes = File.ReadAllBytes(path);
        var extension = GetVerifiedImageExtension(bytes);
        return extension is null ? (null, "Tệp ảnh không hợp lệ.") : (new(bytes, ContentType(extension)), null);
    }

    private static string ContentType(string extension) => extension switch
    {
        ".png" => "image/png",
        ".webp" => "image/webp",
        _ => "image/jpeg"
    };

    private static decimal? NormalizeScore(decimal? score) =>
        score is null ? null : Math.Round(Math.Clamp(score.Value, 0m, 1m), 4);

    private static void DeleteStoredImageIfReplaced(IWebHostEnvironment env, string? oldUrl, string newUrl)
    {
        const string prefix = "/api/giay-to/anh/";
        if (string.IsNullOrWhiteSpace(oldUrl) || oldUrl == newUrl || !oldUrl.StartsWith(prefix, StringComparison.Ordinal)) return;
        var fileName = oldUrl[prefix.Length..];
        if (fileName != Path.GetFileName(fileName)) return;
        var path = Path.Combine(env.ContentRootPath, "Storage", fileName);
        if (File.Exists(path)) File.Delete(path);
    }
}

public sealed record IdentityDocumentRequest(
    string HoTen, string LoaiGiayTo, string SoGiayTo, string MatTruocUrl, string? MatSauUrl);
public sealed record VerifyIdentityRequest(string KetQua, string? GhiChu);
public sealed record EkycRequest(string SelfieBase64);

public sealed record CustomerIdentityConfirmRequest(
    string MaGiayTo, string Cccd, string HoTen, DateOnly NgaySinh, string GioiTinh,
    string QuocTich, string DiaChiThuongTru, DateOnly NgayCap, string NoiCap);
