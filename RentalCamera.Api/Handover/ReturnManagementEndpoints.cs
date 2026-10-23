using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Handover;

public static class ReturnManagementEndpoints
{
    public static void MapReturnManagementEndpoints(this IEndpointRouteBuilder app)
    {
        var returns = app.MapGroup("/api/hoan-tra").RequireAuthorization("Staff");

        returns.MapGet("/cho-nhan", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            int? trang, int? kichThuocTrang, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) && maCuaHang != scope.StoreId)
                return Results.Forbid();
            var storeId = scope.IsAdmin ? maCuaHang?.Trim() : scope.StoreId;
            var page = Math.Max(trang ?? 1, 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.HopDong.AsNoTracking().Where(x => x.TrangThai == "CHO_HOAN_TRA");
            if (!string.IsNullOrWhiteSpace(storeId)) query = query.Where(x => x.MaCuaHang == storeId);
            if (tuNgay.HasValue) query = query.Where(x => x.ThoiGianTraDuKien >= tuNgay.Value.Date);
            if (denNgay.HasValue) query = query.Where(x => x.ThoiGianTraDuKien < denNgay.Value.Date.AddDays(1));
            var total = await query.CountAsync(ct);
            var data = await query.OrderBy(x => x.ThoiGianTraDuKien)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Join(db.KhachThue.AsNoTracking(), h => h.MaKhachThue, k => k.MaKhachThue,
                    (h, k) => new
                    {
                        h.MaHopDong, h.MaKhachThue, k.HoTen, k.SoDienThoai, h.MaCuaHang,
                        h.ThoiGianTraDuKien, h.TongTien, h.TongTienCoc,
                        soThietBi = db.ChiTietHopDong.Count(x => x.MaHopDong == h.MaHopDong),
                        soThietBiDaNhan = db.ChiTietHopDong.Count(x => x.MaHopDong == h.MaHopDong && x.NgayNhanThucTe != null)
                    }).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total,
                tongTrang = total == 0 ? 0 : (int)Math.Ceiling(total / (double)pageSize), duLieu = data });
        }).WithName("Danh sách hợp đồng chờ hoàn trả");

        app.MapGet("/api/hop-dong/{id}/phi-tra-tre", async (
            string id, DateTime? thoiGianTra, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var access = await LoadReturnContract(id, principal, db, ct);
            if (access.Result is not null) return access.Result;
            var quote = await CalculateLateFee(access.Contract!, thoiGianTra ?? DateTime.Now, db, ct);
            return Results.Ok(quote);
        }).RequireAuthorization("Staff").WithName("Tính phí trả trễ");

        app.MapPost("/api/hop-dong/{id}/phi-tra-tre", async (
            string id, LateFeeRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var access = await LoadReturnContract(id, principal, db, ct);
            if (access.Result is not null) return access.Result;
            var quote = await CalculateLateFee(access.Contract!, request.ThoiGianTra ?? DateTime.Now, db, ct);
            if (quote.SoTien <= 0) return Results.Conflict(new { loi = "Hợp đồng chưa phát sinh phí trả trễ.", duKien = quote });
            var detailId = await db.ChiTietHopDong.Where(x => x.MaHopDong == id)
                .OrderBy(x => x.MaChiTietHopDong).Select(x => x.MaChiTietHopDong).FirstOrDefaultAsync(ct);
            if (detailId is null) return Results.Conflict(new { loi = "Hợp đồng chưa có thiết bị." });
            var existing = await db.PhieuPhat.SingleOrDefaultAsync(x => x.MaChiTietHopDong == detailId &&
                x.LoaiViPham == "TRA_TRE" && x.TrangThai == "CHO_XAC_NHAN", ct);
            if (existing is null)
            {
                existing = new PhieuPhat
                {
                    MaPhieuPhat = ApiAccess.NewId("PP"), MaChiTietHopDong = detailId,
                    LoaiViPham = "TRA_TRE", NgayLap = DateTime.Now, TrangThai = "CHO_XAC_NHAN"
                };
                db.PhieuPhat.Add(existing);
            }
            existing.SoTien = quote.SoTien;
            existing.MoTa = string.IsNullOrWhiteSpace(request.GhiChu)
                ? $"Trả trễ {quote.SoNgayTre} ngày, đơn giá {quote.DonGiaMoiNgay:N0} đồng/ngày."
                : request.GhiChu.Trim();
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { phieuPhat = existing, duKien = quote });
        }).RequireAuthorization("Staff").WithName("Lập phí trả trễ tự động");

        app.MapPost("/api/hop-dong/{id}/phi-hu-hong", async (
            string id, DamageFeeRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.ThietBi is null || request.ThietBi.Count == 0)
                return Results.BadRequest(new { loi = "Cần ít nhất một thiết bị để tính phí." });
            var access = await LoadReturnContract(id, principal, db, ct);
            if (access.Result is not null) return access.Result;
            var detailIds = request.ThietBi.Select(x => x.MaChiTietHopDong).Distinct().ToList();
            var details = await db.ChiTietHopDong.Where(x => x.MaHopDong == id && detailIds.Contains(x.MaChiTietHopDong))
                .ToDictionaryAsync(x => x.MaChiTietHopDong, ct);
            if (details.Count != detailIds.Count) return Results.BadRequest(new { loi = "Có thiết bị không thuộc hợp đồng." });

            var created = new List<PhieuPhat>();
            foreach (var item in request.ThietBi)
            {
                if (item.ChiPhiSuaChua < 0 || item.ChiPhiPhuKienThieu < 0)
                    return Results.BadRequest(new { loi = "Chi phí không được âm." });
                foreach (var fee in new[]
                {
                    (Type: "HU_HONG", Amount: item.ChiPhiSuaChua, Note: "Chi phí sửa chữa hư hỏng"),
                    (Type: "THIEU_PHU_KIEN", Amount: item.ChiPhiPhuKienThieu, Note: "Chi phí phụ kiện thiếu")
                }.Where(x => x.Amount > 0))
                {
                    if (await db.PhieuPhat.AnyAsync(x => x.MaChiTietHopDong == item.MaChiTietHopDong &&
                        x.LoaiViPham == fee.Type && x.TrangThai != "HUY", ct))
                        return Results.Conflict(new { loi = $"Thiết bị {item.MaChiTietHopDong} đã có phí {fee.Type} chưa hủy." });
                    var penalty = new PhieuPhat
                    {
                        MaPhieuPhat = ApiAccess.NewId("PP"), MaChiTietHopDong = item.MaChiTietHopDong,
                        LoaiViPham = fee.Type, SoTien = fee.Amount,
                        MoTa = string.IsNullOrWhiteSpace(item.GhiChu) ? fee.Note : $"{fee.Note}: {item.GhiChu.Trim()}",
                        NgayLap = DateTime.Now, TrangThai = "CHO_XAC_NHAN"
                    };
                    db.PhieuPhat.Add(penalty);
                    created.Add(penalty);
                }
            }
            if (created.Count == 0) return Results.BadRequest(new { loi = "Tổng chi phí phải lớn hơn 0." });
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/phieu-phat?maHopDong={id}", new
            {
                maHopDong = id, tongPhi = created.Sum(x => x.SoTien), duLieu = created
            });
        }).RequireAuthorization("Staff").WithName("Tính phí hư hỏng và phụ kiện thiếu");
    }

    private static async Task<(HopDong? Contract, IResult? Result)> LoadReturnContract(
        string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return (null, Results.Forbid());
        var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
        if (contract is null) return (null, Results.NotFound());
        if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return (null, Results.Forbid());
        if (contract.TrangThai is not ("DANG_THUE" or "CHO_HOAN_TRA"))
            return (null, Results.Conflict(new { loi = "Hợp đồng chưa ở bước hoàn trả." }));
        return (contract, null);
    }

    private static async Task<LateFeeQuote> CalculateLateFee(
        HopDong contract, DateTime returnedAt, RentalCameraContext db, CancellationToken ct)
    {
        var extensionDue = await db.PhuLuc.AsNoTracking()
            .Where(x => x.MaHopDong == contract.MaHopDong && x.TrangThai == "DA_XAC_NHAN")
            .MaxAsync(x => (DateTime?)x.ThoiHanTraMoi, ct);
        var due = extensionDue.HasValue && extensionDue > contract.ThoiGianTraDuKien
            ? extensionDue.Value : contract.ThoiGianTraDuKien;
        var lateDays = returnedAt <= due ? 0 : Math.Max(1, (int)Math.Ceiling((returnedAt - due).TotalDays));
        var dailyRate = await db.ChiTietHopDong.AsNoTracking().Where(x => x.MaHopDong == contract.MaHopDong)
            .SumAsync(x => (decimal?)x.DonGia, ct) ?? 0;
        return new LateFeeQuote(contract.MaHopDong, due, returnedAt, lateDays, dailyRate,
            decimal.Round(dailyRate * lateDays, 2));
    }
}

public sealed record LateFeeRequest(DateTime? ThoiGianTra, string? GhiChu);
public sealed record LateFeeQuote(string MaHopDong, DateTime HanTra, DateTime ThoiGianTra,
    int SoNgayTre, decimal DonGiaMoiNgay, decimal SoTien);
public sealed record DamageFeeRequest(List<DamageFeeItemRequest> ThietBi);
public sealed record DamageFeeItemRequest(string MaChiTietHopDong, decimal ChiPhiSuaChua,
    decimal ChiPhiPhuKienThieu, string? GhiChu);
