using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Settlement;

namespace RentalCamera.Api.Penalties;

public static class PenaltyEndpoints
{
    public static void MapPenaltyEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/phieu-phat").RequireAuthorization();

        group.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db, string? maHopDong,
            string? maCuaHang, string? trangThai, CancellationToken ct) =>
        {
            var query = db.PhieuPhat.AsNoTracking()
                .Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
                .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new { x.p, x.c, h });
            if (principal.IsInRole("KHACH_HANG"))
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                query = query.Where(x => x.h.MaKhachThue == customerId);
            }
            else
            {
                var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
                if (scope is null) return Results.Forbid();
                if (!scope.IsAdmin) query = query.Where(x => x.h.MaCuaHang == scope.StoreId);
                else if (!string.IsNullOrWhiteSpace(maCuaHang)) query = query.Where(x => x.h.MaCuaHang == maCuaHang);
            }
            if (!string.IsNullOrWhiteSpace(maHopDong)) query = query.Where(x => x.h.MaHopDong == maHopDong);
            if (!string.IsNullOrWhiteSpace(trangThai)) query = query.Where(x => x.p.TrangThai == trangThai);
            var data = await query.OrderByDescending(x => x.p.NgayLap).Select(x => new
            {
                x.p.MaPhieuPhat, x.h.MaHopDong, x.c.MaThietBi, x.p.MaChiTietHopDong,
                x.p.LoaiViPham, x.p.SoTien, x.p.MoTa, x.p.NgayLap, x.p.TrangThai
            }).ToListAsync(ct);
            return Results.Ok(data);
        });

        group.MapGet("/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var item = await db.PhieuPhat.AsNoTracking().Where(x => x.MaPhieuPhat == id)
                .Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
                .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new
                {
                    x.p.MaPhieuPhat, x.p.MaChiTietHopDong, h.MaHopDong, h.MaKhachThue,
                    h.MaCuaHang, x.c.MaThietBi, x.p.LoaiViPham, x.p.SoTien, x.p.MoTa,
                    x.p.NgayLap, x.p.TrangThai
                }).FirstOrDefaultAsync(ct);
            if (item is null) return Results.NotFound();
            if (principal.IsInRole("KHACH_HANG"))
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                if (item.MaKhachThue != customerId) return Results.Forbid();
            }
            else if (!principal.IsInRole("ADMIN"))
            {
                var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
                if (scope?.StoreId != item.MaCuaHang) return Results.Forbid();
            }
            return Results.Ok(item);
        });

        group.MapPost("", async (PenaltyRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.LoaiViPham is not ("TRA_TRE" or "HU_HONG" or "THIEU_PHU_KIEN" or "KHAC") ||
                request.SoTien < 0 || request.SoTien != Math.Round(request.SoTien,2) || string.IsNullOrWhiteSpace(request.MoTa) || request.MoTa.Length>500) return Results.BadRequest();
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var parent = await db.ChiTietHopDong.AsNoTracking().Where(c=>c.MaChiTietHopDong==request.MaChiTietHopDong).Select(c=>c.MaHopDong).SingleOrDefaultAsync(ct);
            if(parent is null)return Results.NotFound();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            if(RentalPolicy.ProtectedContracts.Contains(parent)||await db.QuyetToanHopDong.AnyAsync(q=>q.MaHopDong==parent,ct))return Results.Conflict(new{loi="Không sửa nghĩa vụ của hợp đồng bảo toàn/đã chốt quyết toán."});
            var detail = await db.ChiTietHopDong.Join(db.HopDong, c => c.MaHopDong, h => h.MaHopDong, (c, h) => new { c, h })
                .SingleOrDefaultAsync(x => x.c.MaChiTietHopDong == request.MaChiTietHopDong, ct);
            if (detail is null) return Results.NotFound();
            if (!scope.IsAdmin && detail.h.MaCuaHang != scope.StoreId) return Results.Forbid();
            if(detail.c.MaBienBanNhanTra!=null){
                var existing=await db.PhieuPhat.SingleOrDefaultAsync(p=>p.MaChiTietHopDong==request.MaChiTietHopDong&&p.LoaiViPham==request.LoaiViPham&&p.TrangThai!="HUY",ct);
                if(existing!=null)return existing.SoTien==request.SoTien&&existing.MoTa==request.MoTa.Trim()?Results.Ok(existing):Results.Conflict(new{loi="Đã có khoản bồi thường cùng loại cho serial này; đối soát trước, không tạo trùng."});
            }
            if(detail.c.MaBienBanNhanTra!=null && (detail.c.LoaiNgoaiLeNhanTra!=null||request.LoaiViPham=="KHAC"))return Results.Conflict(new{loi="Mất thiết bị chỉ ghi ngoại lệ, không lập khoản bồi thường trong đợt này."});
            if(detail.c.MaBienBanNhanTra!=null && request.LoaiViPham=="HU_HONG"&&!detail.c.CoHuHong||
               detail.c.MaBienBanNhanTra!=null && request.LoaiViPham=="THIEU_PHU_KIEN"&&detail.c.ThieuPhuKien!=true)return Results.Conflict(new{loi="Chưa có kết quả kiểm tra phù hợp làm căn cứ."});
            if(request.LoaiViPham=="TRA_TRE"&&detail.h.PhienBanDieuKhoan==RentalPolicy.TermsVersion)
                return Results.Conflict(new{loi="Tiền trả trễ theo phiên bản mới được Backend tính từ thời điểm nhận từng thiết bị và đơn giá gốc; không nhập tùy ý hoặc miễn/giảm."});
            var entity = new PhieuPhat
            {
                MaPhieuPhat = ApiAccess.NewId("PP"), MaChiTietHopDong = request.MaChiTietHopDong,
                LoaiViPham = request.LoaiViPham, SoTien = request.SoTien,
                MoTa = request.MoTa.Trim(), NgayLap = RentalPolicy.LocalNow, TrangThai = "CHO_XAC_NHAN", NguoiLap = ApiAccess.AccountId(principal)!
            };
            db.PhieuPhat.Add(entity);

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created($"/api/phieu-phat/{entity.MaPhieuPhat}", entity);
        }).RequireAuthorization("Staff");

        group.MapPut("/{id}/xac-nhan", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
            await ChangeState(id, "DA_XAC_NHAN", principal, db, ct)).RequireAuthorization("Staff");
        group.MapPut("/{id}/huy", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
            await ChangeState(id, "HUY", principal, db, ct)).RequireAuthorization("Staff");
    }

    private static async Task<IResult> ChangeState(
        string id, string state, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return Results.Forbid();
        var parent=await db.PhieuPhat.Where(p=>p.MaPhieuPhat==id).Join(db.ChiTietHopDong,p=>p.MaChiTietHopDong,c=>c.MaChiTietHopDong,(p,c)=>c.MaHopDong).SingleOrDefaultAsync(ct);
        if(parent is null)return Results.NotFound();
        await using var tx=await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable,ct);
        await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
        if(RentalPolicy.ProtectedContracts.Contains(parent)||await db.QuyetToanHopDong.AnyAsync(q=>q.MaHopDong==parent,ct))return Results.Conflict();
        var row = await db.PhieuPhat.Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
            .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new { x.p, x.c.MaBienBanNhanTra, h })
            .SingleOrDefaultAsync(x => x.p.MaPhieuPhat == id, ct);
        if (row is null) return Results.NotFound();
        if (!scope.IsAdmin && row.h.MaCuaHang != scope.StoreId) return Results.Forbid();
        if(row.MaBienBanNhanTra!=null && state=="DA_XAC_NHAN" && !scope.IsAdmin)return Results.Forbid();
        if(row.p.LoaiViPham=="TRA_TRE"&&row.h.PhienBanDieuKhoan==RentalPolicy.TermsVersion)
            return Results.Conflict(new{loi="Không xác nhận/hủy phiếu trả trễ thủ công cho chính sách mới; sửa sai thời điểm nhận qua API có audit."});
        if (row.p.TrangThai != "CHO_XAC_NHAN") return Results.Conflict(new { loi = "Phiếu phạt đã được xử lý." });
        row.p.TrangThai = state; row.p.NguoiXuLy = ApiAccess.AccountId(principal); row.p.XuLyLucUtc = DateTime.UtcNow;

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Results.Ok(row.p);
    }
}

public sealed record PenaltyRequest(
    string MaChiTietHopDong, string LoaiViPham, decimal SoTien, string MoTa);
