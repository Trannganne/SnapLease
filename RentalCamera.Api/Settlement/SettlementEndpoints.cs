using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Contracts;

namespace RentalCamera.Api.Settlement;

public static class SettlementEndpoints
{
    public static void MapSettlementEndpoints(this IEndpointRouteBuilder app)
    {
        var contracts = app.MapGroup("/api/hop-dong").RequireAuthorization();

        contracts.MapGet("/{id}/quyet-toan", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var result = await CalculateAsync(id, db, ct);
            return result is null ? Results.NotFound() : Results.Ok(result);
        });

        contracts.MapPost("/{id}/hoan-coc", async (
            string id, RefundRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (contract.TrangThai != "CHO_HOAN_TRA") return Results.Conflict(new { loi = "Hợp đồng chưa ở bước hoàn trả/quyết toán." });
            if (await db.ThanhToan.AnyAsync(x => x.MaHopDong == id && x.LoaiThanhToan == "HOAN_COC" && x.TrangThai != "THAT_BAI", ct))
                return Results.Conflict(new { loi = "Đã có giao dịch hoàn cọc cho hợp đồng." });

            var settlement = await CalculateAsync(id, db, ct);
            if (settlement is null || settlement.TienHoanCoc <= 0)
                return Results.Conflict(new { loi = "Không có số tiền cọc cần hoàn." });
            var payment = new ThanhToan
            {
                MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id, SoTien = settlement.TienHoanCoc,
                LoaiThanhToan = "HOAN_COC", PhuongThuc = request.PhuongThuc,
                MaGiaoDich = request.MaGiaoDich?.Trim(), TrangThai = "CHO_THANH_TOAN",
                NoiDungChuyenKhoan = request.NoiDung?.Trim()
            };
            db.ThanhToan.Add(payment);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/thanh-toan/{payment.MaThanhToan}", payment);
        }).RequireAuthorization("Staff");

        app.MapPut("/api/thanh-toan/{id}/xac-nhan-hoan", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var payment = await db.ThanhToan.SingleOrDefaultAsync(x => x.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            var contract = await db.HopDong.SingleAsync(x => x.MaHopDong == payment.MaHopDong, ct);
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (payment.LoaiThanhToan != "HOAN_COC" || payment.TrangThai != "CHO_THANH_TOAN")
                return Results.Conflict(new { loi = "Giao dịch không thể xác nhận hoàn cọc." });
            if(payment.MaYeuCauHuy!=null)return Results.Conflict(new{loi="Dùng xác nhận hoàn hủy có chứng từ; không chuyển hợp đồng đã hủy sang hoàn thành."});
            payment.TrangThai = "DA_HOAN";
            payment.ThoiGian = DateTime.Now;
            contract.TrangThai = "HOAN_THANH";
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { payment.MaThanhToan, payment.TrangThai, contract.MaHopDong, trangThaiHopDong = contract.TrangThai });
        }).RequireAuthorization("Staff");
    }

    private static async Task<SettlementResult?> CalculateAsync(string id, RentalCameraContext db, CancellationToken ct)
    {
        var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
        if (contract is null) return null;
        var extensionCost = await db.PhuLuc.Where(x => x.MaHopDong == id && (x.TrangThai == "DA_XAC_NHAN" || x.TrangThai == "DA_HIEU_LUC"))
            .SumAsync(x => (decimal?)x.ChiPhiPhatSinh, ct) ?? 0;
        var fine = await db.PhieuPhat
            .Where(x => db.ChiTietHopDong.Any(d => d.MaChiTietHopDong == x.MaChiTietHopDong && d.MaHopDong == id)
                && (x.TrangThai == "DA_XAC_NHAN" || x.TrangThai == "DA_THANH_TOAN"))
            .Where(x=>contract.PhienBanDieuKhoan!=RentalPolicy.TermsVersion||x.LoaiViPham!="TRA_TRE")
            .SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
        var deposit = await db.ThanhToan.Where(x => x.MaHopDong == id && x.LoaiThanhToan == "TIEN_COC" && x.TrangThai == "THANH_CONG")
            .SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
        var otherPaid = await db.ThanhToan.Where(x => x.MaHopDong == id && x.TrangThai == "THANH_CONG" && x.LoaiThanhToan != "TIEN_COC" && !x.LoaiThanhToan.StartsWith("HOAN_"))
            .SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
        var payable = contract.TongTien + extensionCost + fine;
        var late=await LateReturnService.QuoteAsync(id,db,ct);
        if(late?.ApDungChinhSachMoi==true) { fine+=late.TongTien??0;payable+=late.TongTien??0; }
        var balance = payable - deposit - otherPaid;
        return new SettlementResult(contract.MaHopDong, contract.TongTien, extensionCost, fine, deposit, otherPaid,
            payable, Math.Max(balance, 0), Math.Max(-balance, 0),late?.ApDungChinhSachMoi==true?late.TongTien:null,late?.LaDuKien??false);
    }
}

public sealed record RefundRequest(string PhuongThuc, string? MaGiaoDich, string? NoiDung);
public sealed record SettlementResult(string MaHopDong, decimal TienThue, decimal PhiGiaHan, decimal TienPhat,
    decimal TienCocDaThu, decimal KhoanKhacDaThu, decimal TongPhaiTra, decimal TienConPhaiThu, decimal TienHoanCoc,decimal? PhiTraTre=null,bool LaDuKien=false);
