using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Rental;

public static class RentalEndpoints
{
    public static void MapRentalEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/lich-trong", async (
            string maCuaHang, string maDongMay, DateTime ngayBatDau, DateTime ngayKetThuc,
            AvailabilityService availability, CancellationToken ct) =>
        {
            if (!ValidPeriod(ngayBatDau, ngayKetThuc))
                return Results.BadRequest(new { loi = "Thời gian thuê không hợp lệ; dùng giờ địa phương không kèm Z/múi giờ, tối đa 90 ngày." });
            var count = await availability.GetAvailableAsync(
                maCuaHang, maDongMay, ngayBatDau, ngayKetThuc, null, null, ct);
            return Results.Ok(new
            {
                maCuaHang, maDongMay, ngayBatDau, ngayKetThuc,
                soLuongConTrong = count
            });
        });

        var carts = app.MapGroup("/api/gio-hang").RequireAuthorization("Customer");

        carts.MapGet("", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.GioHang.AsNoTracking()
                .Where(x => x.MaKhachThue == customerId && x.TrangThai == "DANG_CHON")
                .OrderByDescending(x => x.NgayCapNhat)
                .Select(x => new
                {
                    x.MaGioHang, x.MaCuaHang, x.TrangThai, x.NgayCapNhat,
                    chiTiet = x.ChiTiet.Select(c => new
                    {
                        c.MaChiTietGioHang, c.MaDongMay, c.SoLuong,
                        c.NgayBatDau, c.NgayKetThuc, c.DonGia, c.TienCoc, c.ThanhTien
                    })
                }).ToListAsync(ct);
            return Results.Ok(data);
        });

        carts.MapPost("/items", async (
            AddCartItemRequest request, ClaimsPrincipal principal, RentalCameraContext db,
            AvailabilityService availability, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.MaCuaHang) || string.IsNullOrWhiteSpace(request.MaDongMay) ||
                request.SoLuong is < 1 or > 10 || !ValidPeriod(request.NgayBatDau, request.NgayKetThuc) ||
                request.NgayBatDau <= DateTime.Now)
                return Results.BadRequest(new { loi = "Cửa hàng, dòng máy, số lượng hoặc thời gian thuê không hợp lệ." });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

            var storeExists = await db.CuaHang.AnyAsync(
                x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct);
            var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == request.MaDongMay, ct);
            if (!storeExists || model is null)
                return Results.NotFound(new { loi = "Cửa hàng hoặc dòng máy không tồn tại." });

            var available = await availability.GetAvailableAsync(request.MaCuaHang, request.MaDongMay,
                request.NgayBatDau, request.NgayKetThuc, null, null, ct);
            if (available < request.SoLuong)
                return Results.Conflict(new
                {
                    loi = "Không đủ thiết bị còn trống trong khoảng thời gian này.",
                    soLuongConTrong = available
                });

            var cart = await db.GioHang
                .Where(x => x.MaKhachThue == customerId && x.MaCuaHang == request.MaCuaHang && x.TrangThai == "DANG_CHON")
                .OrderByDescending(x => x.NgayCapNhat).FirstOrDefaultAsync(ct);
            ChiTietGioHang? item = null;
            if (cart is not null)
                item = await db.ChiTietGioHang.SingleOrDefaultAsync(
                    x => x.MaGioHang == cart.MaGioHang && x.MaDongMay == request.MaDongMay, ct);

            var now = DateTime.Now;
            cart ??= new GioHang
            {
                MaGioHang = ApiAccess.NewId("GH"), MaKhachThue = customerId,
                MaCuaHang = request.MaCuaHang, NgayTao = now, NgayCapNhat = now,
                TrangThai = "DANG_CHON"
            };
            if (db.Entry(cart).State == EntityState.Detached) db.GioHang.Add(cart);
            cart.NgayCapNhat = now;

            item ??= new ChiTietGioHang
            {
                MaChiTietGioHang = ApiAccess.NewId("CG"), MaGioHang = cart.MaGioHang
            };
            if (db.Entry(item).State == EntityState.Detached) db.ChiTietGioHang.Add(item);
            ApplyServerPrice(item, model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new
            {
                cart.MaGioHang, item.MaChiTietGioHang, item.ThanhTien, item.TienCoc,
                luuY = "Giỏ hàng chưa giữ chỗ. Gọi endpoint giữ chỗ khi khách bấm Tiếp tục thuê."
            });
        });

        carts.MapDelete("/items/{itemId}", async (
            string itemId, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var item = await db.ChiTietGioHang
                .Join(db.GioHang, i => i.MaGioHang, g => g.MaGioHang, (i, g) => new { i, g })
                .Where(x => x.i.MaChiTietGioHang == itemId && x.g.MaKhachThue == customerId && x.g.TrangThai == "DANG_CHON")
                .Select(x => x.i).FirstOrDefaultAsync(ct);
            if (item is null) return Results.NotFound();
            db.ChiTietGioHang.Remove(item);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        carts.MapPost("/{cartId}/giu-cho", CreateHoldAsync);
        // Alias tam thoi de client cu chuyen doi ma khong bi gay ngay.
        carts.MapPost("/{cartId}/gui-duyet", CreateHoldAsync);

        var holds = app.MapGroup("/api/giu-cho").RequireAuthorization("Customer");

        holds.MapGet("/cua-toi", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var now = DateTime.Now;
            await ExpireCustomerHoldsAsync(customerId, now, db, ct);
            var data = await db.GiuCho.AsNoTracking()
                .Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTao)
                .Select(x => new
                {
                    x.MaGiuCho, x.MaGioHang, x.MaCuaHang, x.NgayTao, x.HetHanLuc, x.TrangThai,
                    conLaiGiay = x.TrangThai == "DANG_GIU" && x.HetHanLuc > now
                        ? EF.Functions.DateDiffSecond(now, x.HetHanLuc) : 0,
                    chiTiet = x.ChiTiet.Select(c => new
                    {
                        c.MaChiTietGiuCho, c.MaDongMay, c.SoLuong, c.NgayBatDau, c.NgayKetThuc
                    })
                }).ToListAsync(ct);
            return Results.Ok(data);
        });

        holds.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (hold is null) return Results.NotFound();
            if (hold.TrangThai == "DANG_GIU" && hold.HetHanLuc <= DateTime.Now)
            {
                hold.TrangThai = "HET_HAN";
                await db.SaveChangesAsync(ct);
            }
            return Results.Ok(new
            {
                hold.MaGiuCho, hold.MaGioHang, hold.MaCuaHang, hold.NgayTao,
                hold.HetHanLuc, hold.TrangThai,
                chiTiet = hold.ChiTiet.Select(c => new
                {
                    c.MaChiTietGiuCho, c.MaDongMay, c.SoLuong, c.NgayBatDau, c.NgayKetThuc
                })
            });
        });

        holds.MapPut("/{id}", async (
            string id, UpdateHoldRequest request, ClaimsPrincipal principal, RentalCameraContext db,
            AvailabilityService availability, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.MaCuaHang) || request.ThietBi.Count == 0 ||
                request.ThietBi.GroupBy(x => x.MaDongMay, StringComparer.OrdinalIgnoreCase).Any(x => x.Count() > 1) ||
                request.ThietBi.Any(x => x.SoLuong is < 1 or > 10 || !ValidPeriod(x.NgayBatDau, x.NgayKetThuc) || x.NgayBatDau <= DateTime.Now))
                return Results.BadRequest(new { loi = "Thông tin giữ chỗ không hợp lệ hoặc trùng dòng máy." });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (hold is null) return Results.NotFound();
            if (hold.TrangThai != "DANG_GIU" || hold.HetHanLuc <= DateTime.Now)
            {
                if (hold.TrangThai == "DANG_GIU")
                {
                    hold.TrangThai = "HET_HAN";
                    await db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);
                }
                return Results.Conflict(new { loi = "Giữ chỗ không còn hiệu lực." });
            }
            if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct))
                return Results.NotFound(new { loi = "Cửa hàng không tồn tại hoặc đang khóa." });

            var modelIds = request.ThietBi.Select(x => x.MaDongMay).ToList();
            var models = await db.DongMay.Where(x => modelIds.Contains(x.MaDongMay)).ToDictionaryAsync(x => x.MaDongMay, ct);
            if (models.Count != modelIds.Count) return Results.NotFound(new { loi = "Có dòng máy không tồn tại." });

            foreach (var line in request.ThietBi)
            {
                var available = await availability.GetAvailableAsync(request.MaCuaHang, line.MaDongMay,
                    line.NgayBatDau, line.NgayKetThuc, hold.MaGiuCho, null, ct);
                if (available < line.SoLuong)
                    return Results.Conflict(new
                    {
                        loi = $"Dòng máy {line.MaDongMay} không đủ số lượng trống.",
                        soLuongConTrong = available
                    });
            }

            var cart = await db.GioHang.Include(x => x.ChiTiet)
                .SingleAsync(x => x.MaGioHang == hold.MaGioHang, ct);
            var targetHold = hold;
            var targetCart = cart;

            if (string.Equals(hold.MaCuaHang, request.MaCuaHang, StringComparison.OrdinalIgnoreCase))
            {
                db.ChiTietGiuCho.RemoveRange(hold.ChiTiet);
                db.ChiTietGioHang.RemoveRange(cart.ChiTiet);
                cart.NgayCapNhat = DateTime.Now;
            }
            else
            {
                // FK cua DB final gan GiuCho voi bo (GioHang, KhachThue, CuaHang), vi vay
                // khong the doi cua hang truc tiep tren ban ghi cu. Tao gio/giu cho moi trong
                // cung transaction, giu nguyen thoi diem het han va huy giu cho cu.
                targetCart = new GioHang
                {
                    MaGioHang = ApiAccess.NewId("GH"), MaKhachThue = customerId,
                    MaCuaHang = request.MaCuaHang, NgayTao = DateTime.Now,
                    NgayCapNhat = DateTime.Now, TrangThai = "DANG_CHON"
                };
                targetHold = new GiuCho
                {
                    MaGiuCho = ApiAccess.NewId("GC"), MaGioHang = targetCart.MaGioHang,
                    MaKhachThue = customerId, MaCuaHang = request.MaCuaHang,
                    NgayTao = hold.NgayTao, HetHanLuc = hold.HetHanLuc,
                    TrangThai = "DANG_GIU"
                };
                db.GioHang.Add(targetCart);
                db.GiuCho.Add(targetHold);
                hold.TrangThai = "DA_HUY";
            }

            foreach (var line in request.ThietBi)
            {
                db.ChiTietGiuCho.Add(new ChiTietGiuCho
                {
                    MaChiTietGiuCho = ApiAccess.NewId("GC"), MaGiuCho = targetHold.MaGiuCho,
                    MaDongMay = line.MaDongMay, SoLuong = line.SoLuong,
                    NgayBatDau = line.NgayBatDau, NgayKetThuc = line.NgayKetThuc
                });
                var cartLine = new ChiTietGioHang
                {
                    MaChiTietGioHang = ApiAccess.NewId("CG"), MaGioHang = targetCart.MaGioHang
                };
                ApplyServerPrice(cartLine, models[line.MaDongMay], line.SoLuong, line.NgayBatDau, line.NgayKetThuc);
                db.ChiTietGioHang.Add(cartLine);
            }

            // Theo DB final: doi lua chon khong duoc reset TTL.
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new
            {
                targetHold.MaGiuCho, targetHold.MaCuaHang,
                targetHold.HetHanLuc, targetHold.TrangThai
            });
        });

        holds.MapPost("/{id}/huy", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var hold = await db.GiuCho.SingleOrDefaultAsync(
                x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (hold is null) return Results.NotFound();
            if (hold.TrangThai != "DANG_GIU")
                return Results.Conflict(new { loi = "Giữ chỗ đã được xử lý." });
            hold.TrangThai = hold.HetHanLuc <= DateTime.Now ? "HET_HAN" : "DA_HUY";
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { hold.MaGiuCho, hold.TrangThai });
        });

        // Endpoint tuong thich de client xem lich su gio hang va hold hien tai.
        app.MapGet("/api/don-thue/cua-toi", async (
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.GioHang.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTao)
                .Select(x => new
                {
                    x.MaGioHang, x.MaCuaHang, x.TrangThai, x.NgayTao,
                    giuCho = db.GiuCho.Where(g => g.MaGioHang == x.MaGioHang)
                        .OrderByDescending(g => g.NgayTao)
                        .Select(g => new { g.MaGiuCho, g.TrangThai, g.HetHanLuc }).FirstOrDefault(),
                    soLuong = x.ChiTiet.Sum(c => c.SoLuong),
                    tongTienThue = x.ChiTiet.Sum(c => c.ThanhTien)
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");
    }

    private static async Task<IResult> CreateHoldAsync(
        string cartId,
        ClaimsPrincipal principal,
        RentalCameraContext db,
        AvailabilityService availability,
        IConfiguration configuration,
        CancellationToken ct)
    {
        var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
        if (customerId is null) return Results.Forbid();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var cart = await db.GioHang.Include(x => x.ChiTiet)
            .SingleOrDefaultAsync(x => x.MaGioHang == cartId && x.MaKhachThue == customerId, ct);
        if (cart is null) return Results.NotFound();
        if (cart.TrangThai != "DANG_CHON" || cart.ChiTiet.Count == 0)
            return Results.Conflict(new { loi = "Giỏ hàng không còn ở trạng thái có thể giữ chỗ hoặc đang trống." });

        var active = await db.GiuCho.SingleOrDefaultAsync(x =>
            x.MaGioHang == cartId && x.TrangThai == "DANG_GIU" && x.HetHanLuc > DateTime.Now, ct);
        if (active is not null)
            return Results.Conflict(new
            {
                loi = "Giỏ hàng đã có giữ chỗ còn hiệu lực.",
                active.MaGiuCho, active.HetHanLuc
            });

        foreach (var item in cart.ChiTiet)
        {
            if (!ValidPeriod(item.NgayBatDau, item.NgayKetThuc) || item.NgayBatDau <= DateTime.Now)
                return Results.Conflict(new { loi = "Thời gian thuê không còn hợp lệ." });
            var available = await availability.GetAvailableAsync(cart.MaCuaHang, item.MaDongMay,
                item.NgayBatDau, item.NgayKetThuc, null, null, ct);
            if (available < item.SoLuong)
                return Results.Conflict(new
                {
                    loi = $"Dòng máy {item.MaDongMay} không đủ số lượng trống.",
                    soLuongConTrong = available
                });
        }

        var now = DateTime.Now;
        var holdMinutes = Math.Clamp(configuration.GetValue("Rental:HoldMinutes", 20), 1, 120);
        var hold = new GiuCho
        {
            MaGiuCho = ApiAccess.NewId("GC"), MaGioHang = cart.MaGioHang,
            MaKhachThue = customerId, MaCuaHang = cart.MaCuaHang,
            NgayTao = now, HetHanLuc = now.AddMinutes(holdMinutes), TrangThai = "DANG_GIU"
        };
        db.GiuCho.Add(hold);
        foreach (var item in cart.ChiTiet)
            db.ChiTietGiuCho.Add(new ChiTietGiuCho
            {
                MaChiTietGiuCho = ApiAccess.NewId("GC"), MaGiuCho = hold.MaGiuCho,
                MaDongMay = item.MaDongMay, SoLuong = item.SoLuong,
                NgayBatDau = item.NgayBatDau, NgayKetThuc = item.NgayKetThuc
            });

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Results.Created($"/api/giu-cho/{hold.MaGiuCho}", new
        {
            hold.MaGiuCho, hold.MaGioHang, hold.TrangThai, hold.NgayTao, hold.HetHanLuc,
            ttlPhut = holdMinutes
        });
    }

    private static async Task ExpireCustomerHoldsAsync(
        string customerId, DateTime now, RentalCameraContext db, CancellationToken ct)
    {
        var expired = await db.GiuCho.Where(x =>
            x.MaKhachThue == customerId && x.TrangThai == "DANG_GIU" && x.HetHanLuc <= now).ToListAsync(ct);
        if (expired.Count == 0) return;
        foreach (var hold in expired) hold.TrangThai = "HET_HAN";
        await db.SaveChangesAsync(ct);
    }

    private static void ApplyServerPrice(
        ChiTietGioHang item, DongMay model, int quantity, DateTime from, DateTime to)
    {
        var days = (decimal)Math.Ceiling((to - from).TotalDays);
        var unitPrice = Math.Round(model.GiaThueNgay * (100 - model.PhanTramGiamGia) / 100, 2);
        item.MaDongMay = model.MaDongMay;
        item.SoLuong = quantity;
        item.NgayBatDau = from;
        item.NgayKetThuc = to;
        item.DonGia = unitPrice;
        item.TienCoc = model.TienCoc;
        item.ThanhTien = unitPrice * days * quantity;
    }

    private static bool ValidPeriod(DateTime from, DateTime to) =>
        from.Kind == DateTimeKind.Unspecified && to.Kind == DateTimeKind.Unspecified &&
        to > from && to - from <= TimeSpan.FromDays(90);
}

public sealed record AddCartItemRequest(
    string MaCuaHang, string MaDongMay, int SoLuong,
    DateTime NgayBatDau, DateTime NgayKetThuc);

public sealed record HoldItemRequest(
    string MaDongMay, int SoLuong, DateTime NgayBatDau, DateTime NgayKetThuc);

public sealed record UpdateHoldRequest(string MaCuaHang, List<HoldItemRequest> ThietBi);
