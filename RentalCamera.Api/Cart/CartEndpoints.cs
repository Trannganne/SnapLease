using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Cart;

public static class CartEndpoints
{
    private const int MaximumQuantity = 10;

    public static void MapCartEndpoints(this IEndpointRouteBuilder app)
    {
        var cart = app.MapGroup("/api/gio-hang").RequireAuthorization("Customer");

        cart.MapGet("", async (
            ClaimsPrincipal principal,
            RentalCameraContext db,
            AvailabilityService availability,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            return Results.Ok(await BuildCurrentCartAsync(customerId, db, availability, ct));
        });

        cart.MapGet("/tam-tinh", async (
            ClaimsPrincipal principal,
            RentalCameraContext db,
            AvailabilityService availability,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            var response = await BuildCurrentCartAsync(customerId, db, availability, ct);
            return Results.Ok(new
            {
                response.MaGioHang,
                response.SoLuongDong,
                response.TongSoLuong,
                response.TongTienThue,
                response.TongTienCoc,
                response.TatCaConDuHang,
                response.ChiTiet
            });
        });

        cart.MapPost("/chi-tiet", async (
            AddCartItemRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            AvailabilityService availability,
            CancellationToken ct) =>
        {
            var validation = ValidateRequest(
                request.MaCuaHang, request.MaDongMay, request.SoLuong,
                request.NgayBatDau, request.NgayKetThuc);
            if (validation is not null) return validation;

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var model = await ValidateCatalogAsync(request.MaCuaHang, request.MaDongMay, db, ct);
            if (model.Error is not null) return model.Error;

            var currentAvailable = await availability.GetAvailableAsync(
                request.MaCuaHang, request.MaDongMay,
                request.NgayBatDau, request.NgayKetThuc, null, null, ct);

            var currentCart = await db.GioHang
                .Include(x => x.ChiTiet)
                .Where(x => x.MaKhachThue == customerId && x.TrangThai == "DANG_CHON")
                .OrderByDescending(x => x.NgayCapNhat)
                .FirstOrDefaultAsync(ct);

            var matchingLine = currentCart?.ChiTiet.FirstOrDefault(x =>
                x.NguonTao == "GIO_HANG" &&
                x.MaCuaHang == request.MaCuaHang &&
                x.MaDongMay == request.MaDongMay &&
                x.NgayBatDau == request.NgayBatDau &&
                x.NgayKetThuc == request.NgayKetThuc);
            var requestedQuantity = request.SoLuong + (matchingLine?.SoLuong ?? 0);

            if (requestedQuantity > MaximumQuantity)
                return Results.BadRequest(new
                {
                    loi = $"Mỗi dòng giỏ hàng chỉ được tối đa {MaximumQuantity} thiết bị."
                });
            if (currentAvailable < requestedQuantity)
                return Results.Conflict(new
                {
                    loi = "Không đủ thiết bị còn trống trong khoảng thời gian đã chọn.",
                    soLuongConTrong = currentAvailable
                });

            var now = DateTime.Now;
            if (currentCart is null)
            {
                currentCart = new GioHang
                {
                    MaGioHang = ApiAccess.NewId("GH"),
                    MaKhachThue = customerId,
                    NgayTao = now,
                    NgayCapNhat = now,
                    TrangThai = "DANG_CHON"
                };
                db.GioHang.Add(currentCart);
            }
            else
            {
                currentCart.NgayCapNhat = now;
            }

            if (matchingLine is null)
            {
                matchingLine = new ChiTietGioHang
                {
                    MaChiTietGioHang = ApiAccess.NewId("CG"),
                    MaGioHang = currentCart.MaGioHang,
                    MaCuaHang = request.MaCuaHang,
                    NguonTao = "GIO_HANG"
                };
                ApplyServerPrice(
                    matchingLine, model.Value!, request.SoLuong,
                    request.NgayBatDau, request.NgayKetThuc);
                db.ChiTietGioHang.Add(matchingLine);
            }
            else
            {
                ApplyServerPrice(
                    matchingLine, model.Value!, requestedQuantity,
                    request.NgayBatDau, request.NgayKetThuc);
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            var response = await BuildCurrentCartAsync(customerId, db, availability, ct);
            return Results.Created($"/api/gio-hang/chi-tiet/{matchingLine.MaChiTietGioHang}", response);
        });

        cart.MapPut("/chi-tiet/{id}", async (
            string id,
            UpdateCartItemRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            AvailabilityService availability,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var line = await db.ChiTietGioHang
                .Include(x => x.GioHang)
                .SingleOrDefaultAsync(x =>
                    x.MaChiTietGioHang == id &&
                    x.NguonTao == "GIO_HANG" &&
                    x.GioHang.MaKhachThue == customerId &&
                    x.GioHang.TrangThai == "DANG_CHON", ct);
            if (line is null) return Results.NotFound();

            var storeId = string.IsNullOrWhiteSpace(request.MaCuaHang)
                ? line.MaCuaHang
                : request.MaCuaHang.Trim();
            var quantity = request.SoLuong ?? line.SoLuong;
            var from = request.NgayBatDau ?? line.NgayBatDau;
            var to = request.NgayKetThuc ?? line.NgayKetThuc;

            var validation = ValidateRequest(storeId, line.MaDongMay, quantity, from, to);
            if (validation is not null) return validation;

            var model = await ValidateCatalogAsync(storeId, line.MaDongMay, db, ct);
            if (model.Error is not null) return model.Error;

            var currentAvailable = await availability.GetAvailableAsync(
                storeId, line.MaDongMay, from, to, null, null, ct);
            if (currentAvailable < quantity)
                return Results.Conflict(new
                {
                    loi = "Không đủ thiết bị còn trống trong khoảng thời gian đã chọn.",
                    soLuongConTrong = currentAvailable
                });

            line.MaCuaHang = storeId;
            ApplyServerPrice(line, model.Value!, quantity, from, to);
            line.GioHang.NgayCapNhat = DateTime.Now;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            return Results.Ok(await BuildCurrentCartAsync(customerId, db, availability, ct));
        });

        cart.MapDelete("/chi-tiet/{id}", async (
            string id,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            var line = await db.ChiTietGioHang
                .Include(x => x.GioHang)
                .SingleOrDefaultAsync(x =>
                    x.MaChiTietGioHang == id &&
                    x.NguonTao == "GIO_HANG" &&
                    x.GioHang.MaKhachThue == customerId &&
                    x.GioHang.TrangThai == "DANG_CHON", ct);
            if (line is null) return Results.NotFound();

            var currentCart = line.GioHang;
            db.ChiTietGioHang.Remove(line);
            await db.SaveChangesAsync(ct);

            var hasAnyLine = await db.ChiTietGioHang.AnyAsync(
                x => x.MaGioHang == currentCart.MaGioHang, ct);
            var isReferenced = await db.GiuCho.AnyAsync(x => x.MaGioHang == currentCart.MaGioHang, ct)
                || await db.HopDong.AnyAsync(x => x.MaGioHang == currentCart.MaGioHang, ct);
            if (!hasAnyLine && !isReferenced)
                db.GioHang.Remove(currentCart);
            else
                currentCart.NgayCapNhat = DateTime.Now;

            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }

    private static IResult? ValidateRequest(
        string? storeId,
        string? modelId,
        int quantity,
        DateTime from,
        DateTime to)
    {
        if (string.IsNullOrWhiteSpace(storeId) || string.IsNullOrWhiteSpace(modelId))
            return Results.BadRequest(new { loi = "Thiếu cửa hàng hoặc dòng máy." });
        if (quantity is < 1 or > MaximumQuantity)
            return Results.BadRequest(new { loi = $"Số lượng phải từ 1 đến {MaximumQuantity}." });
        if (from.Kind != DateTimeKind.Unspecified || to.Kind != DateTimeKind.Unspecified ||
            to <= from || to - from > TimeSpan.FromDays(90) || from <= DateTime.Now)
            return Results.BadRequest(new
            {
                loi = "Thời gian thuê phải ở tương lai, không kèm Z/múi giờ và không vượt quá 90 ngày."
            });
        return null;
    }

    private static async Task<CatalogValidationResult> ValidateCatalogAsync(
        string storeId,
        string modelId,
        RentalCameraContext db,
        CancellationToken ct)
    {
        if (!await db.CuaHang.AnyAsync(
                x => x.MaCuaHang == storeId && x.TrangThai == "HOAT_DONG", ct))
            return new(null, Results.NotFound(new { loi = "Cửa hàng không tồn tại hoặc đang khóa." }));

        var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == modelId, ct);
        if (model is null)
            return new(null, Results.NotFound(new { loi = "Dòng máy không tồn tại." }));
        if (model.TrangThai != "HOAT_DONG")
            return new(null, Results.Conflict(new { loi = "Dòng máy đã ngừng kinh doanh." }));

        if (!await db.ThietBi.AnyAsync(
                x => x.MaCuaHang == storeId && x.MaDongMay == modelId, ct))
            return new(null, Results.NotFound(new
            {
                loi = "Cửa hàng này không có dòng máy đã chọn."
            }));

        return new(model, null);
    }

    private static void ApplyServerPrice(
        ChiTietGioHang line,
        DongMay model,
        int quantity,
        DateTime from,
        DateTime to)
    {
        var days = (int)Math.Ceiling((to - from).TotalDays);
        var unitPrice = Math.Round(
            model.GiaThueNgay * (100 - model.PhanTramGiamGia) / 100, 2);

        line.MaDongMay = model.MaDongMay;
        line.SoLuong = quantity;
        line.NgayBatDau = from;
        line.NgayKetThuc = to;
        line.DonGia = unitPrice;
        line.TienCoc = model.TienCoc;
        line.ThanhTien = unitPrice * days * quantity;
    }

    private static async Task<CartResponse> BuildCurrentCartAsync(
        string customerId,
        RentalCameraContext db,
        AvailabilityService availability,
        CancellationToken ct)
    {
        var currentCart = await db.GioHang.AsNoTracking()
            .Where(x => x.MaKhachThue == customerId && x.TrangThai == "DANG_CHON")
            .OrderByDescending(x => x.NgayCapNhat)
            .Select(x => new { x.MaGioHang, x.NgayTao, x.NgayCapNhat, x.TrangThai })
            .FirstOrDefaultAsync(ct);

        if (currentCart is null)
            return CartResponse.Empty;

        var rawRows = await db.ChiTietGioHang.AsNoTracking()
            .Where(x => x.MaGioHang == currentCart.MaGioHang && x.NguonTao == "GIO_HANG")
            .Join(db.DongMay.AsNoTracking(), line => line.MaDongMay, model => model.MaDongMay,
                (line, model) => new { line, model })
            .Join(db.CuaHang.AsNoTracking(), row => row.line.MaCuaHang, store => store.MaCuaHang,
                (row, store) => new
                {
                    row.line.MaChiTietGioHang,
                    row.line.MaCuaHang,
                    store.TenCuaHang,
                    row.line.MaDongMay,
                    row.model.TenDongMay,
                    AnhDaiDien = db.AnhThietBi
                        .Where(x => x.MaDongMay == row.line.MaDongMay)
                        .OrderByDescending(x => x.LaAnhDaiDien)
                        .ThenBy(x => x.ThuTuHienThi)
                        .Select(x => x.DuongDanAnh)
                        .FirstOrDefault() ?? "",
                    row.line.SoLuong,
                    row.line.NgayBatDau,
                    row.line.NgayKetThuc,
                    row.model.GiaThueNgay,
                    row.model.PhanTramGiamGia,
                    DonGiaSauGiam = row.line.DonGia,
                    TongTienThue = row.line.ThanhTien,
                    TongTienCoc = row.line.TienCoc * row.line.SoLuong
                })
            .OrderBy(x => x.TenCuaHang)
            .ThenBy(x => x.TenDongMay)
            .ToListAsync(ct);

        var rows = rawRows.Select(x => new CartLineRow(
            x.MaChiTietGioHang,
            x.MaCuaHang,
            x.TenCuaHang,
            x.MaDongMay,
            x.TenDongMay,
            x.AnhDaiDien,
            x.SoLuong,
            x.NgayBatDau,
            x.NgayKetThuc,
            (int)Math.Ceiling((x.NgayKetThuc - x.NgayBatDau).TotalDays),
            x.GiaThueNgay,
            x.PhanTramGiamGia,
            x.DonGiaSauGiam,
            x.TongTienThue,
            x.TongTienCoc)).ToList();

        var details = new List<CartLineResponse>(rows.Count);
        foreach (var row in rows)
        {
            var available = await availability.GetAvailableAsync(
                row.MaCuaHang, row.MaDongMay,
                row.NgayBatDau, row.NgayKetThuc, null, null, ct);
            details.Add(new CartLineResponse(
                row.MaChiTietGioHang,
                row.MaCuaHang,
                row.TenCuaHang,
                row.MaDongMay,
                row.TenDongMay,
                row.AnhDaiDien,
                row.SoLuong,
                row.NgayBatDau,
                row.NgayKetThuc,
                row.SoNgayTinhPhi,
                row.GiaThueNgay,
                row.PhanTramGiamGia,
                row.DonGiaSauGiam,
                row.TongTienThue,
                row.TongTienCoc,
                available,
                available >= row.SoLuong));
        }

        return new CartResponse(
            currentCart.MaGioHang,
            currentCart.NgayTao,
            currentCart.NgayCapNhat,
            currentCart.TrangThai,
            details.Count,
            details.Sum(x => x.SoLuong),
            details.Sum(x => x.TongTienThue),
            details.Sum(x => x.TongTienCoc),
            details.All(x => x.ConDuHang),
            details);
    }

    private sealed record CatalogValidationResult(DongMay? Value, IResult? Error);

    private sealed record CartLineRow(
        string MaChiTietGioHang,
        string MaCuaHang,
        string TenCuaHang,
        string MaDongMay,
        string TenDongMay,
        string AnhDaiDien,
        int SoLuong,
        DateTime NgayBatDau,
        DateTime NgayKetThuc,
        int SoNgayTinhPhi,
        decimal GiaThueNgay,
        decimal PhanTramGiamGia,
        decimal DonGiaSauGiam,
        decimal TongTienThue,
        decimal TongTienCoc);
}

public sealed record AddCartItemRequest(
    string MaCuaHang,
    string MaDongMay,
    int SoLuong,
    DateTime NgayBatDau,
    DateTime NgayKetThuc);

public sealed record UpdateCartItemRequest(
    string? MaCuaHang,
    int? SoLuong,
    DateTime? NgayBatDau,
    DateTime? NgayKetThuc);

public sealed record CartLineResponse(
    string MaChiTietGioHang,
    string MaCuaHang,
    string TenCuaHang,
    string MaDongMay,
    string TenDongMay,
    string AnhDaiDien,
    int SoLuong,
    DateTime NgayBatDau,
    DateTime NgayKetThuc,
    int SoNgayTinhPhi,
    decimal GiaThueNgay,
    decimal PhanTramGiamGia,
    decimal DonGiaSauGiam,
    decimal TongTienThue,
    decimal TongTienCoc,
    int SoLuongConTrong,
    bool ConDuHang);

public sealed record CartResponse(
    string? MaGioHang,
    DateTime? NgayTao,
    DateTime? NgayCapNhat,
    string TrangThai,
    int SoLuongDong,
    int TongSoLuong,
    decimal TongTienThue,
    decimal TongTienCoc,
    bool TatCaConDuHang,
    IReadOnlyList<CartLineResponse> ChiTiet)
{
    public static CartResponse Empty { get; } = new(
        null, null, null, "TRONG", 0, 0, 0, 0, true, []);
}
