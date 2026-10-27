using System.Security.Claims;
using Microsoft.Data.SqlClient;
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

    private static readonly ReviewHighlightOption[] DefaultHighlights = [];

    public static bool IsPublic(string? status) => status is null or "CONG_KHAI" or "DA_DUYET";

    public static bool ValidComment(int stars, string? comment) =>
        stars is >= 1 and <= 5 && (stars >= 3 || !string.IsNullOrWhiteSpace(comment))
        && (comment?.Trim().Length ?? 0) <= MaximumCommentLength;

    public static bool CanManageVisibility(ClaimsPrincipal principal) =>
        principal.IsInRole("ADMIN") && !string.IsNullOrWhiteSpace(ApiAccess.AccountId(principal));

    public static bool ValidVisibilityChange(string? status, string? reason) =>
        status is "CONG_KHAI" or "AN" && !string.IsNullOrWhiteSpace(reason) && reason.Trim().Length <= MaximumModerationNoteLength;

    public static async Task CleanupUncommittedImageAsync(Func<Task<bool>> isCommitted, Func<Task> delete)
    {
        // An unavailable DB must throw rather than authorize deletion.
        if (!await isCommitted()) await delete();
    }

    // NULL and DA_DUYET are historical public rows, never fabricated approval events.
    public static IQueryable<DanhGia> PublicReviews(IQueryable<DanhGia> reviews) =>
        reviews.Where(x => x.TrangThaiKiemDuyet == null || x.TrangThaiKiemDuyet == "CONG_KHAI" || x.TrangThaiKiemDuyet == "DA_DUYET");

    public static bool IsDetailUniqueConflict(int number, string message, IEnumerable<string> indexNames) =>
        number is 2601 or 2627 && indexNames.Any(name => message.Contains("'" + name + "'", StringComparison.Ordinal));

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
            if (request.SoSao <= 2 && comment is null)
                return Results.BadRequest(new { errorCode = "REVIEW_COMMENT_REQUIRED", loi = "Vui lòng viết nhận xét khi chọn 1 hoặc 2 sao." });
            if (comment?.Length > MaximumCommentLength)
                return Results.BadRequest(new { loi = $"Nhận xét không được vượt quá {MaximumCommentLength} ký tự." });

            if (request.DiemNoiBat is { Count: > 0 }) return Results.BadRequest(new { code="REVIEW_HIGHLIGHTS_REMOVED" });
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var detail = await db.ChiTietHopDong
                .Join(db.HopDong, row => row.MaHopDong, contract => contract.MaHopDong,
                    (row, contract) => new { row, contract })
                .SingleOrDefaultAsync(x => x.row.MaChiTietHopDong == request.MaChiTietHopDong, ct);
            if (detail is null) return Results.NotFound();
            if (detail.contract.MaKhachThue != customerId) return Results.Forbid();
            if (detail.contract.TrangThai != "HOAN_THANH")
                return Results.Conflict(new { errorCode = "CONTRACT_NOT_COMPLETED", loi = "Chỉ được đánh giá sau khi hoàn tất hợp đồng." });
            if (await db.DanhGia.AnyAsync(x => x.MaChiTietHopDong == request.MaChiTietHopDong, ct))
                return Results.Conflict(new { errorCode = "REVIEW_ALREADY_EXISTS", loi = "Thiết bị trong hợp đồng này đã được đánh giá." });

            var review = new DanhGia
            {
                MaDanhGia = ApiAccess.NewId("DG"),
                MaChiTietHopDong = request.MaChiTietHopDong,
                MaKhachThue = customerId,
                SoSao = request.SoSao,
                NhanXet = comment,
                NgayDanhGia = DateTime.Now,
                TrangThaiKiemDuyet = "CONG_KHAI"
            };
            db.DanhGia.Add(review);

            // Discover the actual unique name: older SQL schemas used an autogenerated name.
            var detailIndexes = await db.Database.SqlQueryRaw<string>("""
                SELECT i.name AS [Value] FROM sys.indexes i
                WHERE i.object_id=OBJECT_ID(N'dbo.DanhGia') AND i.is_unique=1 AND i.is_disabled=0
                AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id
                     AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1
                AND EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns c
                     ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                     WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id
                     AND ic.key_ordinal=1 AND c.name=N'MaChiTietHopDong')
                """).ToListAsync(ct);
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException sql
                && IsDetailUniqueConflict(sql.Number, sql.Message, detailIndexes))
            {
                return Results.Conflict(new { errorCode = "REVIEW_ALREADY_EXISTS", loi = "Thiết bị trong hợp đồng này đã được đánh giá." });
            }

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
            IServiceScopeFactory scopeFactory,
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
            // One SQL row lock serializes upload slots and Admin visibility changes across instances.
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var review = await db.DanhGia.FromSqlInterpolated($"SELECT * FROM dbo.DanhGia WITH (UPDLOCK,HOLDLOCK) WHERE MaDanhGia={id}").SingleOrDefaultAsync(
                x => x.MaDanhGia == id && x.MaKhachThue == customerId, ct);
            if (review is null) return Results.NotFound();
            if (!IsPublic(review.TrangThaiKiemDuyet))
                return Results.Conflict(new { loi = "Không thể thêm ảnh cho đánh giá đang bị ẩn hoặc có trạng thái không được hỗ trợ." });

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
            try
            {
                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);
            }
            catch (Exception ex)
            {
                var logger = loggerFactory.CreateLogger("ReviewImages");
                logger.LogWarning(ex, "Image persistence failed; reconciling before cleanup.");
                using var cleanupTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
                try
                {
                    await transaction.RollbackAsync(cleanupTimeout.Token);
                }
                catch (Exception rollbackError) { logger.LogWarning(rollbackError, "Rollback outcome uncertain."); }
                // Never delete on an uncertain commit. Query the primary in a fresh context.
                try
                {
                    using var scope = scopeFactory.CreateScope();
                    var verifyDb = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
                    await CleanupUncommittedImageAsync(
                        () => verifyDb.AnhDanhGia.AsNoTracking().AnyAsync(x => x.PublicId == upload.PublicId, cleanupTimeout.Token),
                        () => imageStorage.DeleteReviewImageAsync(upload.PublicId, cleanupTimeout.Token));
                }
                catch (Exception cleanupError)
                {
                    // Retain the object if DB verification or deletion fails; never guess it is orphaned.
                    logger.LogError(cleanupError, "Review image requires reconciliation. PublicId={PublicId}", upload.PublicId);
                }
                return Results.Problem("Chưa xác định kết quả lưu ảnh. Hãy tải lại đánh giá để đối soát trước khi thử lại.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
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
            // Count, average, page and materialization observe one protected set of visible rows.
            await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
            var query = PublicReviews(db.DanhGia.AsNoTracking())
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

            await transaction.CommitAsync(ct);
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

        app.MapPut("/api/danh-gia/{id}/kiem-duyet", async (
            string id,
            ModerateReviewRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var status = request.TrangThai?.Trim().ToUpperInvariant();
            if (!CanManageVisibility(principal)) return Results.Forbid();
            if (status is not ("CONG_KHAI" or "AN"))
                return Results.BadRequest(new { loi = "Trạng thái phải là CONG_KHAI hoặc AN." });

            var moderationNote = string.IsNullOrWhiteSpace(request.GhiChu)
                ? null
                : request.GhiChu.Trim();
            if (!ValidVisibilityChange(status, moderationNote))
                return Results.BadRequest(new
                {
                    loi = $"Phải có lý do từ 1 đến {MaximumModerationNoteLength} ký tự cho thao tác ẩn/khôi phục."
                });

            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var review = await db.DanhGia.FromSqlInterpolated($"SELECT * FROM dbo.DanhGia WITH (UPDLOCK,HOLDLOCK) WHERE MaDanhGia={id}")
                .SingleOrDefaultAsync(ct);
            if (review is null) return Results.NotFound();

            review.TrangThaiKiemDuyet = status;
            review.GhiChuKiemDuyet = moderationNote;
            review.NgayKiemDuyet = RentalCamera.Api.Contracts.RentalPolicy.LocalNow; review.NguoiCapNhatHienThi = ApiAccess.AccountId(principal);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return Results.Ok(await GetReviewAsync(db, id, ct));
        }).RequireAuthorization("Admin");

        app.MapGet("/api/danh-gia/{id}/lich-su-hien-thi", () => Results.Json(new { code="REVIEW_HISTORY_REMOVED" }, statusCode:410)).RequireAuthorization("Admin");
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
        // Visibility can change between the public ID query and materialization.
        if (!includePrivateDetails && !IsPublic(row.review.TrangThaiKiemDuyet)) return null;

        ReviewHighlightOption[] highlights = [];
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

public sealed record ModerateReviewRequest(string TrangThai, string? GhiChu);

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
    string? TrangThaiKiemDuyet,
    string? GhiChuKiemDuyet,
    DateTime? NgayKiemDuyet,
    ReviewDeviceResponse ThietBi,
    IReadOnlyList<ReviewHighlightOption> DiemNoiBat,
    IReadOnlyList<ReviewImageResponse> HinhAnh)
{
    public string NhanTrangThaiKiemDuyet => TrangThaiKiemDuyet switch
    {
        null or "CONG_KHAI" => "Công khai",
        "CHO_DUYET" => "Chờ duyệt",
        "DA_DUYET" => "Công khai",
        "AN" or "TU_CHOI" => "Đã ẩn",
        _ => "Chưa xác định trạng thái kiểm duyệt"
    };
    public string TrangThaiHienThi => TrangThaiKiemDuyet switch
    {
        null or "CONG_KHAI" or "DA_DUYET" => "CONG_KHAI",
        "AN" or "TU_CHOI" => "AN",
        _ => "UNKNOWN"
    };
}
