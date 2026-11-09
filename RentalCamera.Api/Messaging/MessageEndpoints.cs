using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Chatbot;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Messaging;

public static class MessageEndpoints
{
    public static void MapMessageEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tin-nhan").RequireAuthorization();

        group.MapGet("/hoi-thoai", async (string? q, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(user, db, ct); if (scope is null) return Results.Forbid();
            var allowed = AllowedCustomers(db, scope);
            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim(); allowed = allowed.Where(k => (k.HoTen ?? "").Contains(term) || k.SoDienThoai.Contains(term));
            }
            var customers = await allowed.Select(k => new { k.MaKhachThue, k.HoTen, k.SoDienThoai }).ToListAsync(ct);
            var ids = customers.Select(x => x.MaKhachThue).ToArray();
            var messages = await db.TinNhan.AsNoTracking().Where(x => ids.Contains(x.MaKhachThue)).OrderByDescending(x => x.GuiLucUtc).ToListAsync(ct);
            var data = customers.Select(k => new { k.MaKhachThue, k.HoTen, k.SoDienThoai,
                tinNhanCuoi = messages.FirstOrDefault(x => x.MaKhachThue == k.MaKhachThue),
                soChuaDoc = messages.Count(x => x.MaKhachThue == k.MaKhachThue && x.LaKhach && x.DaDocLucUtc == null) })
                .OrderByDescending(x => x.tinNhanCuoi?.GuiLucUtc).ToList();
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        group.MapGet("/khach/{customerId}", async (string customerId, DateTime? truoc, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(user, db, ct); if (scope is null) return Results.Forbid();
            if (!await AllowedCustomers(db, scope).AnyAsync(x => x.MaKhachThue == customerId, ct)) return Results.Forbid();
            var query = db.TinNhan.AsNoTracking().Where(x => x.MaKhachThue == customerId);
            if (truoc.HasValue) query = query.Where(x => x.GuiLucUtc < truoc.Value);
            return Results.Ok(await query.OrderByDescending(x => x.GuiLucUtc).Take(50).OrderBy(x => x.GuiLucUtc).ToListAsync(ct));
        }).RequireAuthorization("Staff");

        group.MapPost("/khach/{customerId}", async (string customerId, MessageRequest request, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var validation = Validate(request.NoiDung); if (validation is not null) return validation;
            var scope = await ApiAccess.StaffScopeAsync(user, db, ct); if (scope is null) return Results.Forbid();
            var customer = await AllowedCustomers(db, scope).SingleOrDefaultAsync(x => x.MaKhachThue == customerId, ct); if (customer is null) return Results.Forbid();
            var message = NewMessage(customerId, scope.StoreId, ApiAccess.AccountId(user)!, false, request.NoiDung);
            db.TinNhan.Add(message); ApiAccess.AddNotification(db, customer.MaTaiKhoan, "TIN_NHAN", "Cửa hàng đã trả lời", message.NoiDung, "MESSAGE_RECEIVED", "TIN_NHAN", message.MaTinNhan);
            await db.SaveChangesAsync(ct); return Results.Created($"/api/tin-nhan/khach/{customerId}", message);
        }).RequireAuthorization("Staff");

        group.MapPut("/khach/{customerId}/da-doc", async (string customerId, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(user, db, ct); if (scope is null) return Results.Forbid();
            if (!await AllowedCustomers(db, scope).AnyAsync(x => x.MaKhachThue == customerId, ct)) return Results.Forbid();
            var now = DateTime.UtcNow; var unread = await db.TinNhan.Where(x => x.MaKhachThue == customerId && x.LaKhach && x.DaDocLucUtc == null).ToListAsync(ct);
            foreach (var item in unread) item.DaDocLucUtc = now; await db.SaveChangesAsync(ct); return Results.Ok(new { daDoc = unread.Count, lucUtc = now });
        }).RequireAuthorization("Staff");

        group.MapGet("/cua-toi", async (DateTime? truoc, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(user, db, ct); if (customerId is null) return Results.Forbid();
            var query = db.TinNhan.AsNoTracking().Where(x => x.MaKhachThue == customerId); if (truoc.HasValue) query = query.Where(x => x.GuiLucUtc < truoc.Value);
            return Results.Ok(await query.OrderByDescending(x => x.GuiLucUtc).Take(50).OrderBy(x => x.GuiLucUtc).ToListAsync(ct));
        }).RequireAuthorization("Customer");

        group.MapPost("/cua-toi", async (MessageRequest request, ClaimsPrincipal user, RentalCameraContext db, CancellationToken ct) =>
        {
            var validation = Validate(request.NoiDung); if (validation is not null) return validation;
            var customerId = await ApiAccess.CustomerIdAsync(user, db, ct); if (customerId is null) return Results.Forbid();
            var storeId = await db.HopDong.Where(x => x.MaKhachThue == customerId).OrderByDescending(x => x.NgayTaoHopDong).Select(x => x.MaCuaHang).FirstOrDefaultAsync(ct);
            var message = NewMessage(customerId, storeId, ApiAccess.AccountId(user)!, true, request.NoiDung); db.TinNhan.Add(message); await db.SaveChangesAsync(ct);
            return Results.Created("/api/tin-nhan/cua-toi", message);
        }).RequireAuthorization("Customer").RequireRateLimiting("auth");
    }

    private static IQueryable<KhachThue> AllowedCustomers(RentalCameraContext db, StaffScope scope) => scope.IsAdmin
        ? db.KhachThue
        : db.KhachThue.Where(k => db.HopDong.Any(h => h.MaKhachThue == k.MaKhachThue && h.MaCuaHang == scope.StoreId)
            || db.GiuCho.Any(g => g.MaKhachThue == k.MaKhachThue && g.MaCuaHang == scope.StoreId));
    private static TinNhan NewMessage(string customer, string? store, string sender, bool isCustomer, string content) => new()
        { MaTinNhan = ApiAccess.NewId("TN"), MaKhachThue = customer, MaCuaHang = store, NguoiGui = sender, LaKhach = isCustomer, NoiDung = content.Trim(), GuiLucUtc = DateTime.UtcNow };
    private static IResult? Validate(string? content)
    {
        if (string.IsNullOrWhiteSpace(content) || content.Trim().Length > 1000) return Results.BadRequest(new { loi = "Tin nhắn phải từ 1 đến 1000 ký tự.", code = "INVALID_MESSAGE" });
        if (ChatPrivacy.Sensitive(content)) return Results.BadRequest(new { loi = "Không gửi CCCD, OTP, mật khẩu hoặc thông tin nhạy cảm qua tin nhắn.", code = "SENSITIVE_MESSAGE" });
        return null;
    }
}

public sealed record MessageRequest(string NoiDung);
