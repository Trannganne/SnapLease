using System.Data;
using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Rental;

public sealed record CartHoldEditRequest(string MaCuaHang, DateTime NgayBatDau,
    DateTime NgayKetThuc, CartCheckoutItem[] Items);

public static class CartHoldEditing
{
    // A real interval change receives 20 minutes; reads and branch-only edits retain the deadline.
    public static DateTime ExpiryAfterEdit(GiuCho hold, DateTime start, DateTime end, DateTime utcNow) =>
        hold.ChiTiet.Any(x => x.NgayBatDau != start || x.NgayKetThuc != end)
            ? utcNow.AddMinutes(20) : hold.HetHanLuc;

    public static bool CanEdit(GiuCho hold, DateTime utcNow) => hold.TrangThai == "DANG_GIU" && hold.HetHanLuc > utcNow;
    public static bool ValidRequest(CartHoldEditRequest request) =>
        !string.IsNullOrWhiteSpace(request.MaCuaHang) &&
        RentalEndpoints.ValidPeriod(request.NgayBatDau, request.NgayKetThuc) &&
        request.Items is { Length: > 0 and <= 50 } &&
        request.Items.All(x => x is not null && !string.IsNullOrWhiteSpace(x.Id) && x.PhienBan != Guid.Empty) &&
        request.Items.Select(x => x.Id).Distinct(StringComparer.Ordinal).Count() == request.Items.Length;

    // Compare the complete selected set, including versions on both sides. Never reconstruct legacy selections.
    public static bool MatchesSnapshot(GiuCho hold, IReadOnlyCollection<ChiTietGiuCho> selected,
        IReadOnlyCollection<ChiTietGioHang> lines, CartCheckoutItem[] requested)
    {
        if (selected.Count == 0 || selected.Count != requested.Length || lines.Count != selected.Count ||
            requested.Select(x => x.Id).Distinct(StringComparer.Ordinal).Count() != requested.Length) return false;
        var versions = requested.ToDictionary(x => x.Id, x => x.PhienBan, StringComparer.Ordinal);
        var current = lines.ToDictionary(x => x.MaChiTietGioHang, StringComparer.Ordinal);
        foreach (var item in selected)
        {
            if (!versions.TryGetValue(item.MaChiTietGioHang, out var version) ||
                !current.TryGetValue(item.MaChiTietGioHang, out var line) ||
                item.MaGiuCho != hold.MaGiuCho || item.PhienBanGioHang != version || line.PhienBan != version ||
                line.DaChuyenHopDong || line.NguonTao != "GIO_HANG" || line.MaGioHang != hold.MaGioHang ||
                line.MaDongMay != item.MaDongMay || line.SoLuong != item.SoLuong || line.MaCuaHang != hold.MaCuaHang)
                return false;
        }
        return hold.ChiTiet.Count == selected.Count && hold.ChiTiet.All(detail =>
            current.TryGetValue(detail.MaChiTietGioHang, out var line) &&
            detail.MaDongMay == line.MaDongMay && detail.SoLuong == line.SoLuong &&
            detail.NgayBatDau == line.NgayBatDau && detail.NgayKetThuc == line.NgayKetThuc);
    }

    // Call only after every model passed capacity checks, while holding the owner's serializable transaction.
    public static void Apply(GiuCho hold, IEnumerable<ChiTietGiuCho> selected,
        IEnumerable<ChiTietGioHang> lines, IReadOnlyDictionary<string, DongMay> models, CartHoldEditRequest request,
        DateTime utcNow)
    {
        if (!CanEdit(hold, utcNow)) throw new InvalidOperationException("An expired hold cannot be revived.");
        var expiry = ExpiryAfterEdit(hold, request.NgayBatDau, request.NgayKetThuc, utcNow);
        var selections = selected.ToDictionary(x => x.MaChiTietGioHang, StringComparer.Ordinal);
        hold.MaCuaHang = request.MaCuaHang;
        foreach (var line in lines)
        {
            line.MaCuaHang = request.MaCuaHang;
            RentalEndpoints.ApplyServerPrice(line, models[line.MaDongMay], line.SoLuong,
                request.NgayBatDau, request.NgayKetThuc);
            line.PhienBan = Guid.NewGuid();
            selections[line.MaChiTietGioHang].PhienBanGioHang = line.PhienBan;
        }
        foreach (var detail in hold.ChiTiet)
        {
            detail.NgayBatDau = request.NgayBatDau;
            detail.NgayKetThuc = request.NgayKetThuc;
        }
        hold.HetHanLuc = expiry;
        // NgayTao, model quantities and the selected IDs stay fixed.
    }

    public static async Task<IResult> UpdateAsync(string id, CartHoldEditRequest request,
        ClaimsPrincipal principal, RentalCameraContext db, AvailabilityService availability, CancellationToken ct)
    {
        if (!ValidRequest(request) || request.NgayBatDau <= RentalPolicy.LocalNow)
            return Results.BadRequest(new { code = "INVALID_CART_HOLD_EDIT", loi = "Thông tin cập nhật không hợp lệ." });
        var customer = await ApiAccess.CustomerIdAsync(principal, db, ct);
        if (customer is null) return Results.Forbid();
        try
        {
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            // Creation, cancellation, cart editing and contract confirmation all use this lock.
            await TransactionLock.AcquireAsync(db, "cart:" + customer, ct);
            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customer, ct);
            if (hold is null) return Results.NotFound();
            if (!CanEdit(hold, DateTime.UtcNow) ||
                await db.HopDong.AnyAsync(x => x.MaGiuCho == id, ct))
                return Results.Conflict(new { code = "HOLD_NOT_EDITABLE", loi = "Giữ chỗ đã hết hạn hoặc không còn được chỉnh sửa." });
            var selected = await db.ChiTietGiuCho.Where(x => x.MaGiuCho == id).ToListAsync(ct);
            var ids = selected.Select(x => x.MaChiTietGioHang).ToArray();
            var lines = await db.ChiTietGioHang.Where(x => ids.Contains(x.MaChiTietGioHang) &&
                x.GioHang.MaKhachThue == customer && x.GioHang.TrangThai == "DANG_CHON").ToListAsync(ct);
            if (!MatchesSnapshot(hold, selected, lines, request.Items))
                return Results.Conflict(new { code = "CART_VERSION_CONFLICT", loi = "Lựa chọn hoặc phiên bản đã thay đổi. Hãy kiểm tra lại giữ chỗ." });
            if (hold.MaCuaHang == request.MaCuaHang && hold.ChiTiet.All(x =>
                    x.NgayBatDau == request.NgayBatDau && x.NgayKetThuc == request.NgayKetThuc))
            {
                // A no-op does not reprice, advance versions or write a deadline.
                var unchanged = await CartEndpoints.HoldDtoAsync(id, customer, db, ct);
                await tx.CommitAsync(ct);
                return Results.Ok(unchanged);
            }
            if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct))
                return Results.Conflict(new { code = "BRANCH_NOT_FOUND", loi = "Chi nhánh mới không hoạt động." });
            var modelIds = lines.Select(x => x.MaDongMay).Distinct().ToArray();
            var models = await db.DongMay.Where(x => modelIds.Contains(x.MaDongMay)).ToDictionaryAsync(x => x.MaDongMay, ct);
            if (models.Count != modelIds.Length) return Results.Conflict(new { code = "MODEL_NOT_FOUND", loi = "Không tìm thấy đầy đủ mẫu thiết bị." });
            foreach (var group in CartEndpoints.HoldQuantities(lines).OrderBy(x => x.Key, StringComparer.Ordinal))
            {
                var available = await availability.GetAvailableAsync(request.MaCuaHang, group.Key,
                    request.NgayBatDau, request.NgayKetThuc, hold.MaGiuCho, null, ct);
                if (available < group.Value)
                    return Results.Conflict(new { code = "INSUFFICIENT_DEVICES", loi = "Lựa chọn mới không đủ thiết bị. Lượt giữ chỗ cũ được giữ nguyên nếu còn hạn." });
            }
            var originalExpiry = hold.HetHanLuc;
            var updatedAt = DateTime.UtcNow;
            if (originalExpiry <= updatedAt)
                return Results.Conflict(new { code = "HOLD_NOT_EDITABLE", loi = "Giữ chỗ đã hết hạn trong lúc kiểm tra." });
            Apply(hold, selected, lines, models, request, updatedAt);
            await db.SaveChangesAsync(ct);
            // Construct the response before commit so it describes this transaction's versions.
            var result = await CartEndpoints.HoldDtoAsync(id, customer, db, ct);
            if (originalExpiry <= DateTime.UtcNow)
                return Results.Conflict(new { code = "HOLD_NOT_EDITABLE", loi = "Giữ chỗ đã hết hạn; cập nhật chưa được áp dụng." });
            await tx.CommitAsync(ct);
            return Results.Ok(result);
        }
        catch (DbUpdateException)
        {
            return Results.Conflict(new { code = "CART_VERSION_CONFLICT", loi = "Có cập nhật đồng thời. Hãy kiểm tra lại giữ chỗ." });
        }
        catch (SqlException error) when (error.Number is 1205 or 51001)
        {
            return Results.Conflict(new { code = "CONCURRENT_OPERATION", loi = "Giữ chỗ đang được xử lý. Hãy kiểm tra lại; không tự gửi lại." });
        }
    }
}
