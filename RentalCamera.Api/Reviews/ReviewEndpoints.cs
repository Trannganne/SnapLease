using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Media;

namespace RentalCamera.Api.Reviews;

public static class ReviewEndpoints
{
    private const int MaximumCommentLength = 500;
    private const int MaximumModerationNoteLength = 500;
    private const int MaximumImageCount = 4;

    private static readonly ReviewHighlightOption[] DefaultHighlights =
    [
        new("CHAT_LUONG_HINH_ANH_TOT", "Chất lượng hình ảnh tốt"),
        new("THIET_BI_HOAT_DONG_ON_DINH", "Thiết bị hoạt động ổn định"),
        new("NGOAI_HINH_CON_MOI", "Ngoại hình còn mới"),
        new("PIN_SU_DUNG_TOT", "Pin sử dụng tốt"),
        new("DE_SU_DUNG", "Dễ sử dụng"),
        new("PHU_KIEN_DAY_DU", "Phụ kiện đầy đủ")
    ];

    private static readonly HashSet<string> DefaultHighlightCodes =
        DefaultHighlights.Select(x => x.Ma).ToHashSet(StringComparer.Ordinal);

    public static void MapReviewEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/danh-gia/bieu-mau/{maChiTietHopDong}", async (
            string maChiTietHopDong,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            var form = await db.ChiTietHopDong.AsNoTracking()
                .Where(x => x.MaChiTietHopDong == maChiTietHopDong)
                .Join(db.HopDong.AsNoTracking(), detail => detail.MaHopDong, contract => contract.MaHopDong,
                    (detail, contract) => new { detail, contract })
                .Join(db.ThietBi.AsNoTracking(), row => row.detail.MaThietBi, device => device.MaThietBi,
                    (row, device) => new { row.detail, row.contract, device })
                .Join(db.DongMay.AsNoTracking(), row => row.device.MaDongMay, model => model.MaDongMay,
                    (row, model) => new { row.detail, row.contract, row.device, model })
                .Join(db.ThuongHieu.AsNoTracking(), row => row.model.MaThuongHieu, brand => brand.MaThuongHieu,
                    (row, brand) => new { row.detail, row.contract, row.device, row.model, brand })
                .Join(db.DanhMuc.AsNoTracking(), row => row.model.MaDanhMuc, category => category.MaDanhMuc,
                    (row, category) => new
                    {
                        row.detail.MaChiTietHopDong,
                        row.contract.MaHopDong,
                        row.contract.MaKhachThue,
                        row.contract.TrangThai,
                        row.device.MaThietBi,
                        row.device.SoSerial,
                        row.model.MaDongMay,
                        row.model.TenDongMay,
                        row.brand.TenThuongHieu,
                        category.TenDanhMuc,
                        AnhDaiDien = db.AnhThietBi
                            .Where(x => x.MaDongMay == row.model.MaDongMay)
                            .OrderByDescending(x => x.LaAnhDaiDien)
                            .ThenBy(x => x.ThuTuHienThi)
                            .Select(x => x.DuongDanAnh)
                            .FirstOrDefault() ?? ""
                    })
                .SingleOrDefaultAsync(ct);

            if (form is null) return Results.NotFound();
            if (form.MaKhachThue != customerId) return Results.Forbid();

            var existingReviewId = await db.DanhGia.AsNoTracking()
                .Where(x => x.MaChiTietHopDong == maChiTietHopDong)
                .Select(x => x.MaDanhGia)
                .SingleOrDefaultAsync(ct);
            var completed = form.TrangThai == "HOAN_THANH";
            var canReview = completed && existingReviewId is null;

            return Results.Ok(new
            {
                form.MaChiTietHopDong,
                form.MaHopDong,
                form.MaThietBi,
                form.SoSerial,
                form.MaDongMay,
                form.TenDongMay,
                form.TenThuongHieu,
                form.TenDanhMuc,
                form.AnhDaiDien,
                TrangThaiHopDong = form.TrangThai,
                ChinhHang = true,
                DuocDanhGia = canReview,
                LyDoKhongTheDanhGia = canReview
                    ? null
                    : existingReviewId is not null
                        ? "Thiết bị trong hợp đồng này đã được đánh giá."
                        : "Chỉ được đánh giá sau khi hoàn tất hợp đồng.",
                MaDanhGiaDaCo = existingReviewId,
                GioiHanNhanXet = MaximumCommentLength,
                GioiHanAnh = MaximumImageCount,
                DiemNoiBatMacDinh = DefaultHighlights
            });
        }).RequireAuthorization("Customer");

        app.MapPost("/api/danh-gia", async (
            CreateReviewRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            if (request.SoSao is < 1 or > 5)
                return Results.BadRequest(new { loi = "Số sao phải từ 1 đến 5." });

            var comment = string.IsNullOrWhiteSpace(request.NhanXet) ? null : request.NhanXet.Trim();
            if (comment?.Length > MaximumCommentLength)
                return Results.BadRequest(new { loi = $"Nhận xét không được vượt quá {MaximumCommentLength} ký tự." });

            var highlightCodes = (request.DiemNoiBat ?? [])
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim().ToUpperInvariant())
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            var invalidCodes = highlightCodes.Where(x => !DefaultHighlightCodes.Contains(x)).ToArray();
            if (invalidCodes.Length > 0)
                return Results.BadRequest(new
                {
                    loi = "Có mã điểm nổi bật không hợp lệ.",
                    maKhongHopLe = invalidCodes,
                    maHopLe = DefaultHighlights
                });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var detail = await db.ChiTietHopDong
                .Join(db.HopDong, row => row.MaHopDong, contract => contract.MaHopDong,
                    (row, contract) => new { row, contract })
                .SingleOrDefaultAsync(x => x.row.MaChiTietHopDong == request.MaChiTietHopDong, ct);
            if (detail is null) return Results.NotFound();
            if (detail.contract.MaKhachThue != customerId) return Results.Forbid();
            if (detail.contract.TrangThai != "HOAN_THANH")
                return Results.Conflict(new { loi = "Chỉ được đánh giá sau khi hoàn tất hợp đồng." });
            if (await db.DanhGia.AnyAsync(x => x.MaChiTietHopDong == request.MaChiTietHopDong, ct))
                return Results.Conflict(new { loi = "Thiết bị trong hợp đồng này đã được đánh giá." });

            var review = new DanhGia
            {
                MaDanhGia = ApiAccess.NewId("DG"),
                MaChiTietHopDong = request.MaChiTietHopDong,
                MaKhachThue = customerId,
                SoSao = request.SoSao,
                NhanXet = comment,
                NgayDanhGia = DateTime.Now,
                // Đánh giá được công khai ngay. Chỉ ADMIN mới có thể ẩn khi nội dung vi phạm.
                TrangThaiKiemDuyet = "DA_DUYET",
                NgayKiemDuyet = DateTime.Now
            };
            db.DanhGia.Add(review);
            db.DanhGiaDiemNoiBat.AddRange(highlightCodes.Select(code => new DanhGiaDiemNoiBat
            {
                MaDanhGia = review.MaDanhGia,
                MaDiemNoiBat = code
            }));
            await db.SaveChangesAsync(ct);

            var response = await GetReviewAsync(db, review.MaDanhGia, ct);
            return Results.Created($"/api/danh-gia/{review.MaDanhGia}", response);
        }).RequireAuthorization("Customer");

        app.MapPost("/api/danh-gia/{id}/anh", async (
            string id,
            IFormFile anh,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CloudinaryImageStorage imageStorage,
            ILoggerFactory loggerFactory,
            CancellationToken ct) =>
        {
            if (anh.Length == 0)
                return Results.BadRequest(new { loi = "Chưa chọn file ảnh." });
            if (anh.Length > imageStorage.MaximumBytes)
                return Results.BadRequest(new
                {
                    loi = $"Ảnh không được vượt quá {imageStorage.MaximumBytes / 1024 / 1024} MB."
                });
            if (anh.ContentType is not ("image/jpeg" or "image/png" or "image/webp"))
                return Results.BadRequest(new { loi = "Chỉ chấp nhận ảnh JPEG, PNG hoặc WEBP." });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var review = await db.DanhGia.SingleOrDefaultAsync(
                x => x.MaDanhGia == id && x.MaKhachThue == customerId, ct);
            if (review is null) return Results.NotFound();
            if (review.TrangThaiKiemDuyet == "TU_CHOI")
                return Results.Conflict(new { loi = "Đánh giá đã bị ẩn nên không thể thêm ảnh." });

            var imageCount = await db.AnhDanhGia.CountAsync(x => x.MaDanhGia == id, ct);
            if (imageCount >= MaximumImageCount)
                return Results.Conflict(new { loi = $"Mỗi đánh giá chỉ được có tối đa {MaximumImageCount} ảnh." });

            CloudinaryUploadResult upload;
            try
            {
                upload = await imageStorage.UploadReviewImageAsync(anh, id, ct);
            }
            catch (InvalidOperationException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Thiếu cấu hình Cloudinary.");
                return Results.Problem(ex.Message, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
            catch (HttpRequestException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Upload ảnh đánh giá thất bại.");
                return Results.Problem("Không thể tải ảnh lên Cloudinary.",
                    statusCode: StatusCodes.Status502BadGateway);
            }

            var image = new AnhDanhGia
            {
                MaAnhDanhGia = ApiAccess.NewId("ADG"),
                MaDanhGia = id,
                DuongDanAnh = upload.SecureUrl,
                PublicId = upload.PublicId,
                ThuTu = (byte)(imageCount + 1),
                NgayTao = DateTime.Now
            };
            db.AnhDanhGia.Add(image);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/danh-gia/{id}", new ReviewImageResponse(
                image.MaAnhDanhGia, image.DuongDanAnh, image.ThuTu));
        }).DisableAntiforgery().RequireAuthorization("Customer");

        app.MapGet("/api/dong-may/{id}/danh-gia", async (
            string id,
            int? trang,
            int? kichThuocTrang,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var page = Math.Max(1, trang ?? 1);
            var size = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.DanhGia.AsNoTracking()
                .Where(x => x.TrangThaiKiemDuyet == "DA_DUYET")
                .Where(x => db.ChiTietHopDong.Any(detail =>
                    detail.MaChiTietHopDong == x.MaChiTietHopDong
                    && db.ThietBi.Any(device =>
                        device.MaThietBi == detail.MaThietBi && device.MaDongMay == id)));

            var total = await query.CountAsync(ct);
            var average = await query.AverageAsync(x => (double?)x.SoSao, ct);
            var reviewIds = await query.OrderByDescending(x => x.NgayDanhGia)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(x => x.MaDanhGia)
                .ToListAsync(ct);
            var reviews = new List<ReviewResponse>(reviewIds.Count);
            foreach (var reviewId in reviewIds)
            {
                var review = await GetReviewAsync(db, reviewId, ct, includePrivateDetails: false);
                if (review is not null) reviews.Add(review);
            }

            return Results.Ok(new
            {
                trang = page,
                kichThuocTrang = size,
                tongSo = total,
                diemTrungBinh = average,
                duLieu = reviews
            });
        });

        app.MapGet("/api/danh-gia/cua-toi", async (
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var reviewIds = await db.DanhGia.AsNoTracking()
                .Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayDanhGia)
                .Select(x => x.MaDanhGia)
                .ToListAsync(ct);
            var reviews = new List<ReviewResponse>(reviewIds.Count);
            foreach (var reviewId in reviewIds)
            {
                var review = await GetReviewAsync(db, reviewId, ct);
                if (review is not null) reviews.Add(review);
            }

            return Results.Ok(reviews);
        }).RequireAuthorization("Customer");

        app.MapPut("/api/danh-gia/{id}", async (
            string id,
            UpdateReviewRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            if (request.SoSao is < 1 or > 5)
                return Results.BadRequest(new { loi = "Số sao phải từ 1 đến 5." });
            var comment = string.IsNullOrWhiteSpace(request.NhanXet) ? null : request.NhanXet.Trim();
            if (comment?.Length > MaximumCommentLength)
                return Results.BadRequest(new { loi = $"Nhận xét không được vượt quá {MaximumCommentLength} ký tự." });
            var highlightCodes = (request.DiemNoiBat ?? [])
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim().ToUpperInvariant())
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            var invalidCodes = highlightCodes.Where(x => !DefaultHighlightCodes.Contains(x)).ToArray();
            if (invalidCodes.Length > 0)
                return Results.BadRequest(new { loi = "Có mã điểm nổi bật không hợp lệ.", maKhongHopLe = invalidCodes });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var review = await db.DanhGia.SingleOrDefaultAsync(
                x => x.MaDanhGia == id && x.MaKhachThue == customerId, ct);
            if (review is null) return Results.NotFound();
            if (review.TrangThaiKiemDuyet == "TU_CHOI")
                return Results.Conflict(new { loi = "Đánh giá đã bị Admin ẩn nên không thể chỉnh sửa." });

            review.SoSao = request.SoSao;
            review.NhanXet = comment;
            var oldHighlights = await db.DanhGiaDiemNoiBat.Where(x => x.MaDanhGia == id).ToListAsync(ct);
            db.DanhGiaDiemNoiBat.RemoveRange(oldHighlights);
            db.DanhGiaDiemNoiBat.AddRange(highlightCodes.Select(code => new DanhGiaDiemNoiBat
            {
                MaDanhGia = id,
                MaDiemNoiBat = code
            }));
            await db.SaveChangesAsync(ct);
            return Results.Ok(await GetReviewAsync(db, id, ct));
        }).RequireAuthorization("Customer");

        app.MapDelete("/api/danh-gia/{id}", async (
            string id,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CloudinaryImageStorage imageStorage,
            ILoggerFactory loggerFactory,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var review = await db.DanhGia.SingleOrDefaultAsync(
                x => x.MaDanhGia == id && x.MaKhachThue == customerId, ct);
            if (review is null) return Results.NotFound();
            var images = await db.AnhDanhGia.Where(x => x.MaDanhGia == id).ToListAsync(ct);
            try
            {
                foreach (var image in images)
                    await imageStorage.DeleteReviewImageAsync(image.PublicId, ct);
            }
            catch (InvalidOperationException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Thiếu cấu hình Cloudinary khi xóa đánh giá {ReviewId}.", id);
                return Results.Problem(ex.Message, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
            catch (HttpRequestException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Xóa ảnh đánh giá {ReviewId} thất bại.", id);
                return Results.Problem("Không thể xóa ảnh đánh giá trên Cloudinary.",
                    statusCode: StatusCodes.Status502BadGateway);
            }

            db.DanhGia.Remove(review);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        }).RequireAuthorization("Customer");

        app.MapPut("/api/danh-gia/{id}/an", async (
            string id,
            HideReviewRequest request,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var moderationNote = string.IsNullOrWhiteSpace(request.LyDo)
                ? null
                : request.LyDo.Trim();
            if (moderationNote is null)
                return Results.BadRequest(new { loi = "Cần nhập lý do ẩn đánh giá vi phạm." });
            if (moderationNote?.Length > MaximumModerationNoteLength)
                return Results.BadRequest(new
                {
                    loi = $"Lý do ẩn không được vượt quá {MaximumModerationNoteLength} ký tự."
                });

            var review = await db.DanhGia.SingleOrDefaultAsync(x => x.MaDanhGia == id, ct);
            if (review is null) return Results.NotFound();

            review.TrangThaiKiemDuyet = "TU_CHOI";
            review.GhiChuKiemDuyet = moderationNote;
            review.NgayKiemDuyet = DateTime.Now;
            await db.SaveChangesAsync(ct);
            return Results.Ok(await GetReviewAsync(db, id, ct));
        }).RequireAuthorization("Admin");

        app.MapPut("/api/danh-gia/{id}/khoi-phuc", async (
            string id,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var review = await db.DanhGia.SingleOrDefaultAsync(x => x.MaDanhGia == id, ct);
            if (review is null) return Results.NotFound();

            review.TrangThaiKiemDuyet = "DA_DUYET";
            review.GhiChuKiemDuyet = null;
            review.NgayKiemDuyet = DateTime.Now;
            await db.SaveChangesAsync(ct);
            return Results.Ok(await GetReviewAsync(db, id, ct));
        }).RequireAuthorization("Admin");
    }

    private static async Task<ReviewResponse?> GetReviewAsync(
        RentalCameraContext db,
        string reviewId,
        CancellationToken ct,
        bool includePrivateDetails = true)
    {
        var row = await db.DanhGia.AsNoTracking()
            .Where(x => x.MaDanhGia == reviewId)
            .Join(db.KhachThue.AsNoTracking(), review => review.MaKhachThue, customer => customer.MaKhachThue,
                (review, customer) => new { review, customer })
            .Join(db.ChiTietHopDong.AsNoTracking(), row => row.review.MaChiTietHopDong,
                detail => detail.MaChiTietHopDong, (row, detail) => new { row.review, row.customer, detail })
            .Join(db.HopDong.AsNoTracking(), row => row.detail.MaHopDong, contract => contract.MaHopDong,
                (row, contract) => new { row.review, row.customer, row.detail, contract })
            .Join(db.ThietBi.AsNoTracking(), row => row.detail.MaThietBi, device => device.MaThietBi,
                (row, device) => new { row.review, row.customer, row.detail, row.contract, device })
            .Join(db.DongMay.AsNoTracking(), row => row.device.MaDongMay, model => model.MaDongMay,
                (row, model) => new { row.review, row.customer, row.detail, row.contract, row.device, model })
            .Join(db.ThuongHieu.AsNoTracking(), row => row.model.MaThuongHieu, brand => brand.MaThuongHieu,
                (row, brand) => new { row.review, row.customer, row.detail, row.contract, row.device, row.model, brand })
            .Join(db.DanhMuc.AsNoTracking(), row => row.model.MaDanhMuc, category => category.MaDanhMuc,
                (row, category) => new
                {
                    row.review,
                    row.customer.HoTen,
                    row.detail.MaChiTietHopDong,
                    row.contract.MaHopDong,
                    row.device.MaThietBi,
                    row.device.SoSerial,
                    row.model.MaDongMay,
                    row.model.TenDongMay,
                    row.brand.TenThuongHieu,
                    category.TenDanhMuc,
                    AnhDaiDien = db.AnhThietBi
                        .Where(x => x.MaDongMay == row.model.MaDongMay)
                        .OrderByDescending(x => x.LaAnhDaiDien)
                        .ThenBy(x => x.ThuTuHienThi)
                        .Select(x => x.DuongDanAnh)
                        .FirstOrDefault() ?? ""
                })
            .SingleOrDefaultAsync(ct);
        if (row is null) return null;

        var highlightCodes = await db.DanhGiaDiemNoiBat.AsNoTracking()
            .Where(x => x.MaDanhGia == reviewId)
            .Select(x => x.MaDiemNoiBat)
            .ToListAsync(ct);
        var highlightCodeSet = highlightCodes.ToHashSet(StringComparer.Ordinal);
        var highlights = DefaultHighlights.Where(x => highlightCodeSet.Contains(x.Ma)).ToArray();
        var images = await db.AnhDanhGia.AsNoTracking()
            .Where(x => x.MaDanhGia == reviewId)
            .OrderBy(x => x.ThuTu)
            .Select(x => new ReviewImageResponse(x.MaAnhDanhGia, x.DuongDanAnh, x.ThuTu))
            .ToListAsync(ct);

        return new ReviewResponse(
            row.review.MaDanhGia,
            includePrivateDetails ? row.MaChiTietHopDong : null,
            includePrivateDetails ? row.MaHopDong : null,
            includePrivateDetails ? row.review.MaKhachThue : null,
            row.HoTen ?? "",
            row.review.SoSao,
            row.review.NhanXet,
            row.review.NgayDanhGia,
            row.review.TrangThaiKiemDuyet,
            includePrivateDetails ? row.review.GhiChuKiemDuyet : null,
            includePrivateDetails ? row.review.NgayKiemDuyet : null,
            new ReviewDeviceResponse(
                includePrivateDetails ? row.MaThietBi : null,
                includePrivateDetails ? row.SoSerial : null,
                row.MaDongMay,
                row.TenDongMay,
                row.TenThuongHieu,
                row.TenDanhMuc,
                row.AnhDaiDien,
                true),
            highlights,
            images);
    }
}

public sealed record CreateReviewRequest(
    string MaChiTietHopDong,
    byte SoSao,
    string? NhanXet,
    List<string>? DiemNoiBat);

public sealed record UpdateReviewRequest(
    byte SoSao,
    string? NhanXet,
    List<string>? DiemNoiBat);

public sealed record HideReviewRequest(string LyDo);

public sealed record ReviewHighlightOption(string Ma, string Ten);

public sealed record ReviewImageResponse(string MaAnhDanhGia, string DuongDanAnh, byte ThuTu);

public sealed record ReviewDeviceResponse(
    string? MaThietBi,
    string? SoSerial,
    string MaDongMay,
    string TenDongMay,
    string TenThuongHieu,
    string TenDanhMuc,
    string AnhDaiDien,
    bool ChinhHang);

public sealed record ReviewResponse(
    string MaDanhGia,
    string? MaChiTietHopDong,
    string? MaHopDong,
    string? MaKhachThue,
    string HoTenKhachHang,
    byte SoSao,
    string? NhanXet,
    DateTime NgayDanhGia,
    string TrangThaiKiemDuyet,
    string? GhiChuKiemDuyet,
    DateTime? NgayKiemDuyet,
    ReviewDeviceResponse ThietBi,
    IReadOnlyList<ReviewHighlightOption> DiemNoiBat,
    IReadOnlyList<ReviewImageResponse> HinhAnh);
