using System.Buffers.Binary;
using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

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
            var path = Path.GetFullPath(Path.Combine(storagePath, fileName));
            if (!path.StartsWith(storagePath) || !File.Exists(path))
                return Results.NotFound();

            // Lấy MaGiayTo từ DB để kiểm tra quyền
            var relativeUrl = $"/api/giay-to/anh/{fileName}";
            var giayTo = await db.GiayToTuyThan.AsNoTracking().FirstOrDefaultAsync(x => x.MatTruocUrl == relativeUrl || x.MatSauUrl == relativeUrl, ct);
            if (giayTo != null)
            {
                var role = principal.FindFirstValue(ClaimTypes.Role);
                if (role == "KHACH_HANG")
                {
                    var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                    if (customerId == null || giayTo.MaKhachThue != customerId) return Results.Forbid();
                }
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
                string.IsNullOrWhiteSpace(request.SoGiayTo) || string.IsNullOrWhiteSpace(request.MatTruocUrl))
                return Results.BadRequest(new { loi = "Thông tin giấy tờ không hợp lệ." });
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (await db.GiayToTuyThan.AnyAsync(x => x.SoGiayTo == request.SoGiayTo.Trim() && x.MaKhachThue != customerId, ct))
                return Results.Conflict(new { loi = "Số giấy tờ đã được sử dụng bởi khách thuê khác." });
            
            var writtenFiles = new List<string>();
            (string? Url, string? Error) SaveBase64Image(string data) {
                if (!data.StartsWith("data:image")) return (data, null);
                var parts = data.Split(',');
                if (parts.Length != 2) return (data, null);
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
                return Results.Created($"/api/giay-to/{entity.MaGiayTo}", entity);
            } catch (Exception) {
                foreach (var file in writtenFiles) {
                    if (File.Exists(file)) File.Delete(file);
                }
                throw;
            }
        }).RequireAuthorization("Customer");

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
                    g.MatTruocUrl, g.MatSauUrl, g.NgayTaiLen
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        group.MapPut("/{id}/xac-minh", async (
            string id, VerifyIdentityRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
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
            ApiAccess.AddNotification(db, customer.MaTaiKhoan, "XAC_MINH_GIAY_TO", "Kết quả xác minh giấy tờ",
                request.KetQua == "HOP_LE" ? "Giấy tờ của bạn đã được xác minh." : $"Giấy tờ bị từ chối. {request.GhiChu}");
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
}

public sealed record IdentityDocumentRequest(
    string HoTen, string LoaiGiayTo, string SoGiayTo, string MatTruocUrl, string? MatSauUrl);
public sealed record VerifyIdentityRequest(string KetQua, string? GhiChu);

public sealed record CustomerIdentityConfirmRequest(
    string MaGiayTo, string Cccd, string HoTen, DateOnly NgaySinh, string GioiTinh,
    string QuocTich, string DiaChiThuongTru, DateOnly NgayCap, string NoiCap);
