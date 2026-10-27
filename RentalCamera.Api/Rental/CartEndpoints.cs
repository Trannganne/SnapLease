using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Contracts;

namespace RentalCamera.Api.Rental;

public static class CartEndpoints
{
    public static bool Compatible(IEnumerable<ChiTietGioHang> items)
    {
        var keys = items.Select(x => new { x.MaCuaHang, x.NgayBatDau, x.NgayKetThuc }).Distinct().ToList();
        return keys.Count == 1;
    }

    public static void MapCartEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/gio-hang").RequireAuthorization("Customer");
        group.MapPut("/giu-cho/{id}", CartHoldEditing.UpdateAsync);
        group.MapGet("/checkout/{key}",async(string key,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);if(customer is null)return Results.Forbid();
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"cart:"+customer,ct);
            var previous=await db.IdempotencyKey.AsNoTracking().SingleOrDefaultAsync(x=>x.IdempotencyKey==key&&x.MaKhachThue==customer&&x.LoaiThaoTac=="CART_CHECKOUT",ct);
            if(previous is null)return Results.NotFound();
            var result=await HoldDtoAsync(previous.MaThucThe,customer,db,ct);await tx.CommitAsync(ct);return Results.Ok(result);
        });
        group.MapGet("", async (ClaimsPrincipal principal, RentalCameraContext db, AvailabilityService availability, CancellationToken ct) =>
        {
            var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customer is null) return Results.Forbid();
            var lines = await ActiveLines(db, customer).OrderBy(x => x.MaChiTietGioHang).ToListAsync(ct);
            var result = new List<object>();
            foreach (var line in lines) result.Add(await ToDtoAsync(line, db, availability, ct));
            return Results.Ok(result);
        });
        group.MapPost("/chi-tiet", async (CartLineRequest request, ClaimsPrincipal principal, RentalCameraContext db, AvailabilityService availability, CancellationToken ct) =>
        {
            if (!Valid(request)) return Results.BadRequest(new { loi = "Số lượng/thời gian thuê không hợp lệ." });
            var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customer is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "cart:" + customer, ct);
            var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == request.MaDongMay, ct);
            if (model is null || !await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct))
                return Results.NotFound();
            var cart = await db.GioHang.FirstOrDefaultAsync(x => x.MaKhachThue == customer && x.TrangThai == "DANG_CHON", ct);
            if (cart is null)
            {
                cart = new GioHang { MaGioHang = ApiAccess.NewId("GH"), MaKhachThue = customer,
                    NgayTao = DateTime.UtcNow, NgayCapNhat = DateTime.UtcNow, TrangThai = "DANG_CHON" };
                db.GioHang.Add(cart);
            }
            var line = new ChiTietGioHang { MaChiTietGioHang = ApiAccess.NewId("CG"), MaGioHang = cart.MaGioHang,
                MaCuaHang = request.MaCuaHang, NguonTao = "GIO_HANG" };
            RentalEndpoints.ApplyServerPrice(line, model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);
            db.ChiTietGioHang.Add(line);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created("/api/gio-hang/chi-tiet/" + line.MaChiTietGioHang, await ToDtoAsync(line, db, availability, ct));
        });
        group.MapPut("/chi-tiet/{id}", async (string id, CartLineRequest request, ClaimsPrincipal principal, RentalCameraContext db, AvailabilityService availability, CancellationToken ct) =>
        {
            if (!Valid(request) || request.PhienBan is null) return Results.BadRequest();
            var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customer is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "cart:" + customer, ct);
            var line = await ActiveLines(db, customer).SingleOrDefaultAsync(x => x.MaChiTietGioHang == id, ct);
            if (line is null) return Results.NotFound();
            if (line.PhienBan != request.PhienBan) return Results.Conflict(new { loi = "Mục giỏ hàng đã thay đổi. Hãy tải lại." });
            var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == request.MaDongMay, ct);
            if (model is null || !await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct)) return Results.NotFound();
            line.MaCuaHang = request.MaCuaHang;
            line.PhienBan = Guid.NewGuid();
            RentalEndpoints.ApplyServerPrice(line, model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(await ToDtoAsync(line, db, availability, ct));
        });
        group.MapDelete("/chi-tiet/{id}", async (string id, Guid phienBan, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customer is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "cart:" + customer, ct);
            var line = await ActiveLines(db, customer).SingleOrDefaultAsync(x => x.MaChiTietGioHang == id, ct);
            if (line is null) return Results.NotFound();
            if (line.PhienBan != phienBan) return Results.Conflict(new { loi = "Mục đã thay đổi. Hãy tải lại." });
            // Retire from the active list; keep hold/history references intact.
            line.DaChuyenHopDong = true;
            line.PhienBan = Guid.NewGuid();
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.NoContent();
        });
        group.MapPost("/checkout", async ([FromHeader(Name="Idempotency-Key")] string key, CartCheckoutRequest request,
            ClaimsPrincipal principal, RentalCameraContext db, AvailabilityService availability, IConfiguration config, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(key) || key.Length > 100 || request.Items is not { Length: > 0 and <= 50 }
                || request.Items.Any(x=>x is null||string.IsNullOrWhiteSpace(x.Id))
                || request.Items.Select(x => x.Id).Distinct().Count() != request.Items.Length) return Results.BadRequest();
            var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customer is null) return Results.Forbid();
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request.Items.OrderBy(x => x.Id)))));
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "cart:" + customer, ct);
            var previous = await db.IdempotencyKey.SingleOrDefaultAsync(x => x.IdempotencyKey == key && x.MaKhachThue == customer && x.LoaiThaoTac == "CART_CHECKOUT", ct);
            if (previous is not null)
            {
                if (previous.PayloadHash != hash) return Results.Conflict(new { loi = "Idempotency-Key đã dùng cho nội dung khác." });
                return Results.Ok(await HoldDtoAsync(previous.MaThucThe, customer, db, ct));
            }
            var ids = request.Items.Select(x => x.Id).ToArray();
            var lines = await ActiveLines(db, customer).Where(x => ids.Contains(x.MaChiTietGioHang)).ToListAsync(ct);
            if (lines.Count != ids.Length) return Results.Conflict(new { loi = "Một mục không còn trong giỏ hàng." });
            if (lines.Any(x => request.Items.Single(i => i.Id == x.MaChiTietGioHang).PhienBan != x.PhienBan))
                return Results.Conflict(new { loi = "Giỏ hàng đã thay đổi. Hãy tải lại trước checkout." });
            if (!Compatible(lines) || lines.Any(x => x.NgayBatDau <= RentalPolicy.LocalNow))
                return Results.Conflict(new { loi = "Chọn các mục cùng chi nhánh, cùng thời điểm thuê trong tương lai." });
            var first = lines[0];
            if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == first.MaCuaHang && x.TrangThai == "HOAT_DONG", ct)) return Results.Conflict(new { loi = "Chi nhánh không hoạt động." });
            foreach (var modelGroup in lines.GroupBy(x => x.MaDongMay).OrderBy(x => x.Key))
            {
                var count = await availability.GetAvailableAsync(first.MaCuaHang, modelGroup.Key, first.NgayBatDau, first.NgayKetThuc, null, null, ct);
                if (count < modelGroup.Sum(x => x.SoLuong)) return Results.Conflict(new { loi = "Không đủ thiết bị cho toàn bộ lựa chọn.", maDongMay = modelGroup.Key });
            }
            var now = DateTime.UtcNow;
            var hold = new GiuCho { MaGiuCho = ApiAccess.NewId("GC"), MaGioHang = first.MaGioHang, MaKhachThue = customer,
                MaCuaHang = first.MaCuaHang, NgayTao = now, HetHanLuc = now.AddMinutes(Math.Clamp(config.GetValue("Rental:HoldMinutes",20),1,120)), TrangThai = "DANG_GIU" };
            foreach (var line in lines) hold.ChiTiet.Add(new ChiTietGiuCho {
                MaChiTietGiuCho = ApiAccess.NewId("GC"), MaGiuCho = hold.MaGiuCho,
                MaChiTietGioHang = line.MaChiTietGioHang, PhienBanGioHang = line.PhienBan,
                MaDongMay = line.MaDongMay, SoLuong = line.SoLuong,
                NgayBatDau = line.NgayBatDau, NgayKetThuc = line.NgayKetThuc });
            db.GiuCho.Add(hold);
            db.IdempotencyKey.Add(new IdempotencyKeyRecord { IdempotencyKey=key, MaKhachThue=customer,
                LoaiThaoTac="CART_CHECKOUT", PayloadHash=hash, MaThucThe=hold.MaGiuCho, NgayTao=now });
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created("/api/giu-cho/" + hold.MaGiuCho, await HoldDtoAsync(hold.MaGiuCho, customer, db, ct));
        });
    }

    public static Dictionary<string,int> HoldQuantities(IEnumerable<ChiTietGioHang> lines)=>
        lines.GroupBy(x=>x.MaDongMay).ToDictionary(x=>x.Key,x=>x.Sum(l=>l.SoLuong));
    public static bool SameSelectedVersion(ChiTietGiuCho selection,ChiTietGioHang line)=>
        selection.MaChiTietGioHang==line.MaChiTietGioHang&&selection.PhienBanGioHang==line.PhienBan;

    private static IQueryable<ChiTietGioHang> ActiveLines(RentalCameraContext db, string customer) =>
        db.ChiTietGioHang.Where(x => x.GioHang.MaKhachThue == customer && x.GioHang.TrangThai == "DANG_CHON"
            && x.NguonTao == "GIO_HANG" && !x.DaChuyenHopDong && !db.ChiTietGiuCho.Any(l=>l.MaChiTietGioHang==x.MaChiTietGioHang
                && db.HopDong.Any(h=>h.MaGiuCho==l.MaGiuCho)));
    private static bool Valid(CartLineRequest r) => r.SoLuong is >=1 and <=10 && RentalEndpoints.ValidPeriod(r.NgayBatDau, r.NgayKetThuc) && r.NgayBatDau > RentalPolicy.LocalNow;
    private static async Task<object> ToDtoAsync(ChiTietGioHang line, RentalCameraContext db, AvailabilityService availability, CancellationToken ct)
    {
        var model = await db.DongMay.AsNoTracking().SingleAsync(x => x.MaDongMay == line.MaDongMay, ct);
        var store = await db.CuaHang.AsNoTracking().SingleAsync(x => x.MaCuaHang == line.MaCuaHang, ct);
        var quote = RentalEndpoints.CalculatePrice(model, line.SoLuong, line.NgayBatDau, line.NgayKetThuc);
        var available = await availability.GetAvailableAsync(line.MaCuaHang, line.MaDongMay, line.NgayBatDau, line.NgayKetThuc, null, null, ct);
        var image = await db.AnhThietBi.AsNoTracking().Where(x => x.MaDongMay == line.MaDongMay).OrderByDescending(x => x.LaAnhDaiDien).Select(x => x.DuongDanAnh).FirstOrDefaultAsync(ct);
        return new { line.MaChiTietGioHang, line.PhienBan, line.MaCuaHang, store.TenCuaHang, line.MaDongMay, model.TenDongMay,
            line.SoLuong, line.NgayBatDau, line.NgayKetThuc, anhDaiDien=image, baoGia=quote, soLuongConTrong=available,
            khaDung=store.TrangThai == "HOAT_DONG" && line.NgayBatDau > RentalPolicy.LocalNow && available >= line.SoLuong };
    }
    internal static async Task<object> HoldDtoAsync(string id, string customer, RentalCameraContext db, CancellationToken ct)
    {
        var hold = await db.GiuCho.AsNoTracking().SingleAsync(x => x.MaGiuCho == id && x.MaKhachThue == customer, ct);
        var confirmed = await db.KhachThue.AnyAsync(x => x.MaKhachThue == customer && x.DaXacNhanThongTin, ct);
        var lines = await db.ChiTietGiuCho.AsNoTracking().Where(x => x.MaGiuCho == id).ToListAsync(ct);
        var quotes = new List<RentalEndpoints.PriceQuote>();
        var items=new List<object>();
        var store=await db.CuaHang.AsNoTracking().SingleAsync(s=>s.MaCuaHang==hold.MaCuaHang,ct);
        foreach (var line in lines) {
            var model = await db.DongMay.AsNoTracking().SingleAsync(x => x.MaDongMay == line.MaDongMay, ct);
            var quote=RentalEndpoints.CalculatePrice(model, line.SoLuong, line.NgayBatDau, line.NgayKetThuc);
            quotes.Add(quote);
            items.Add(new{maChiTietGioHang=line.MaChiTietGioHang,phienBan=line.PhienBanGioHang,
                hold.MaCuaHang,store.TenCuaHang,line.MaDongMay,model.TenDongMay,line.SoLuong,line.NgayBatDau,line.NgayKetThuc,
                baoGia=quote,khaDung=true,soLuongConTrong=line.SoLuong});
        }
        return new { hold.MaGiuCho, hold.MaCuaHang, hetHanLuc=DateTime.SpecifyKind(hold.HetHanLuc,DateTimeKind.Utc),
            thoiGianServer=DateTime.UtcNow, trangThai=hold.TrangThai == "DANG_GIU" && hold.HetHanLuc <= DateTime.UtcNow ? "HET_HAN" : hold.TrangThai,
            daXacNhanThongTin=confirmed, baoGia=quotes,cartItems=items,
            chiTiet=lines.Select(c=>new{c.MaChiTietGiuCho,c.MaDongMay,c.SoLuong,c.NgayBatDau,c.NgayKetThuc}) };
    }
}
public sealed record CartLineRequest(string MaCuaHang, string MaDongMay, int SoLuong, DateTime NgayBatDau, DateTime NgayKetThuc, Guid? PhienBan);
public sealed record CartCheckoutItem(string Id, Guid PhienBan);
public sealed record CartCheckoutRequest(CartCheckoutItem[] Items);
