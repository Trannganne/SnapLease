using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Infrastructure;

public static class ApiAccess
{
    public static string NewId(string prefix) =>
        prefix + Guid.NewGuid().ToString("N")[..(20 - prefix.Length)].ToUpperInvariant();

    public static string? AccountId(ClaimsPrincipal principal) =>
        principal.FindFirstValue(ClaimTypes.NameIdentifier);

    public static async Task<string?> CustomerIdAsync(
        ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var accountId = AccountId(principal);
        return await db.KhachThue.AsNoTracking()
            .Where(x => x.MaTaiKhoan == accountId)
            .Select(x => x.MaKhachThue)
            .FirstOrDefaultAsync(ct);
    }

    public static async Task<StaffScope?> StaffScopeAsync(
        ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        if (principal.IsInRole("ADMIN")) return new StaffScope(null, null, true);
        var accountId = AccountId(principal);
        return await db.NhanVien.AsNoTracking()
            .Where(x => x.MaTaiKhoan == accountId && x.TrangThai == "HOAT_DONG")
            .Select(x => new StaffScope(x.MaNhanVien, x.MaCuaHang, false))
            .FirstOrDefaultAsync(ct);
    }

    public static async Task<bool> CanAccessContractAsync(
        string contractId, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        if (principal.IsInRole("ADMIN")) return true;
        if (principal.IsInRole("KHACH_HANG"))
        {
            var customerId = await CustomerIdAsync(principal, db, ct);
            return customerId is not null && await db.HopDong.AsNoTracking()
                .AnyAsync(x => x.MaHopDong == contractId && x.MaKhachThue == customerId, ct);
        }

        var scope = await StaffScopeAsync(principal, db, ct);
        return scope?.StoreId is not null && await db.HopDong.AsNoTracking()
            .AnyAsync(x => x.MaHopDong == contractId && x.MaCuaHang == scope.StoreId, ct);
    }

    public static void AddNotification(
        RentalCameraContext db, string accountId, string type, string title, string content)
    {
        db.ThongBao.Add(new ThongBao
        {
            MaThongBao = NewId("TB"),
            MaTaiKhoan = accountId,
            Loai = type,
            TieuDe = title,
            NoiDung = content,
            ThoiGianGui = DateTime.Now,
            DaDoc = false
        });
    }
}

public sealed record StaffScope(string? EmployeeId, string? StoreId, bool IsAdmin);
