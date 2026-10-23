using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Customers;

public static class CustomerManagementEndpoints
{
    public static void MapCustomerManagementEndpoints(this IEndpointRouteBuilder app)
    {
        var customers = app.MapGroup("/api/khach-hang").RequireAuthorization("Staff");

        customers.MapGet("", async (
            string? tuKhoa, string? trangThaiTaiKhoan, bool? daXacNhanThongTin,
            string? maCuaHang, int? trang, int? kichThuocTrang,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) && maCuaHang != scope.StoreId)
                return Results.Forbid();
            var storeId = scope.IsAdmin ? maCuaHang?.Trim() : scope.StoreId;
            var page = Math.Max(trang ?? 1, 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);

            var query = db.KhachThue.AsNoTracking().Join(db.TaiKhoan.AsNoTracking(),
                customer => customer.MaTaiKhoan, account => account.MaTaiKhoan,
                (customer, account) => new { customer, account });
            if (!string.IsNullOrWhiteSpace(storeId))
                query = query.Where(x => db.HopDong.Any(h => h.MaKhachThue == x.customer.MaKhachThue && h.MaCuaHang == storeId));
            if (!string.IsNullOrWhiteSpace(tuKhoa))
            {
                var keyword = tuKhoa.Trim();
                query = query.Where(x => x.customer.MaKhachThue.Contains(keyword) ||
                    (x.customer.HoTen != null && x.customer.HoTen.Contains(keyword)) ||
                    x.customer.SoDienThoai.Contains(keyword) ||
                    (x.customer.Email != null && x.customer.Email.Contains(keyword)) ||
                    (x.customer.CCCD != null && x.customer.CCCD.Contains(keyword)));
            }
            if (!string.IsNullOrWhiteSpace(trangThaiTaiKhoan))
                query = query.Where(x => x.account.TrangThai == trangThaiTaiKhoan.Trim().ToUpper());
            if (daXacNhanThongTin.HasValue)
                query = query.Where(x => x.customer.DaXacNhanThongTin == daXacNhanThongTin.Value);

            var total = await query.CountAsync(ct);
            var data = await query.OrderBy(x => x.customer.HoTen).ThenBy(x => x.customer.MaKhachThue)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new
                {
                    x.customer.MaKhachThue, x.customer.HoTen, x.customer.SoDienThoai,
                    x.customer.Email, x.customer.CCCD, x.customer.DaXacNhanThongTin,
                    x.account.MaTaiKhoan, x.account.TenDangNhap, x.account.TrangThai,
                    soHopDong = db.HopDong.Count(h => h.MaKhachThue == x.customer.MaKhachThue &&
                        (storeId == null || h.MaCuaHang == storeId))
                }).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total,
                tongTrang = total == 0 ? 0 : (int)Math.Ceiling(total / (double)pageSize), duLieu = data });
        }).WithName("Danh sách khách hàng Staff Admin");

        customers.MapGet("/{id}", async (
            string id, string? maCuaHang, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var storeId = scope.IsAdmin ? maCuaHang?.Trim() : scope.StoreId;
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) && maCuaHang != scope.StoreId)
                return Results.Forbid();
            if (!scope.IsAdmin && !await db.HopDong.AnyAsync(x => x.MaKhachThue == id && x.MaCuaHang == storeId, ct))
                return Results.Forbid();

            var customer = await db.KhachThue.AsNoTracking().Where(x => x.MaKhachThue == id)
                .Join(db.TaiKhoan.AsNoTracking(), x => x.MaTaiKhoan, x => x.MaTaiKhoan,
                    (customer, account) => new { customer, account }).SingleOrDefaultAsync(ct);
            if (customer is null) return Results.NotFound();
            var documents = await db.GiayToTuyThan.AsNoTracking().Where(x => x.MaKhachThue == id)
                .OrderByDescending(x => x.NgayTaiLen).ToListAsync(ct);
            var contractQuery = db.HopDong.AsNoTracking().Where(x => x.MaKhachThue == id);
            if (!string.IsNullOrWhiteSpace(storeId)) contractQuery = contractQuery.Where(x => x.MaCuaHang == storeId);
            var summary = await contractQuery.GroupBy(_ => 1).Select(x => new
            {
                tongHopDong = x.Count(), dangThue = x.Count(h => h.TrangThai == "DANG_THUE"),
                hoanThanh = x.Count(h => h.TrangThai == "HOAN_THANH"), daHuy = x.Count(h => h.TrangThai == "DA_HUY")
            }).FirstOrDefaultAsync(ct);
            return Results.Ok(new { hoSo = customer.customer, taiKhoan = new
            {
                customer.account.MaTaiKhoan, customer.account.TenDangNhap,
                customer.account.TrangThai, customer.account.NgayTao
            }, giayTo = documents, thongKeHopDong = summary });
        }).WithName("Chi tiết khách hàng Staff Admin");

        customers.MapGet("/{id}/hop-dong", async (
            string id, string? maCuaHang, string? trangThai, int? trang, int? kichThuocTrang,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) && maCuaHang != scope.StoreId)
                return Results.Forbid();
            var storeId = scope.IsAdmin ? maCuaHang?.Trim() : scope.StoreId;
            var query = db.HopDong.AsNoTracking().Where(x => x.MaKhachThue == id);
            if (!string.IsNullOrWhiteSpace(storeId)) query = query.Where(x => x.MaCuaHang == storeId);
            if (!string.IsNullOrWhiteSpace(trangThai)) query = query.Where(x => x.TrangThai == trangThai.Trim().ToUpper());
            var page = Math.Max(trang ?? 1, 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var total = await query.CountAsync(ct);
            var data = await query.OrderByDescending(x => x.NgayTaoHopDong)
                .Skip((page - 1) * pageSize).Take(pageSize).Select(x => new
                {
                    x.MaHopDong, x.MaCuaHang, x.NgayTaoHopDong, x.NgayKy, x.TrangThai,
                    x.ThoiGianBanGiao, x.ThoiGianTraDuKien, x.TongTien, x.TongTienCoc
                }).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total, duLieu = data });
        }).WithName("Lịch sử hợp đồng theo khách hàng");
    }
}
