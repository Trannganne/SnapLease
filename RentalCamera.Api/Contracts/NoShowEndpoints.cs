using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public static class NoShowEndpoints
{
    public static void MapNoShowEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/hop-dong/can-kiem-tra-nhan",async(ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var cutoff=RentalPolicy.LocalNow.AddHours(-2);
            var rows=await db.HopDong.AsNoTracking().Where(h=>(h.TrangThai=="DA_KY"||h.TrangThai=="CHO_BAN_GIAO")&&h.ThoiGianBanGiao<=cutoff
                &&(scope.IsAdmin||h.MaCuaHang==scope.StoreId)&&!db.ChiTietHopDong.Any(d=>d.MaHopDong==h.MaHopDong&&d.NgayGiaoThucTe!=null))
                .Select(h=>new{h.MaHopDong,h.MaCuaHang,h.ThoiGianBanGiao,canKiemTra=true,tuDongHuy=false}).ToListAsync(ct);
            return Results.Ok(rows);
        }).RequireAuthorization("Staff");
        app.MapPost("/api/hop-dong/{id}/xac-nhan-khong-den",async(string id,NoShowEvidence request,ClaimsPrincipal principal,RentalCameraContext db,BranchWorkingHours hours,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            if(string.IsNullOrWhiteSpace(request.GhiChu)||request.GhiChu.Length>500||string.IsNullOrWhiteSpace(request.KenhLienHe)||string.IsNullOrWhiteSpace(request.KetQuaLienHe)||request.LienHeLucUtc==default||request.LienHeLucUtc.Kind!=DateTimeKind.Utc||request.LienHeLucUtc>DateTime.UtcNow)return Results.BadRequest();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var h=await db.HopDong.SingleOrDefaultAsync(h=>h.MaHopDong==id,ct);if(h is null)return Results.NotFound();
            if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            if(!await CancellationEndpoints.EligibleAsync(h,db,ct)||RentalPolicy.LocalNow<h.ThoiGianBanGiao.AddHours(2))return Results.Conflict();
            if(request.GioHenDaXacNhan!=h.ThoiGianBanGiao)return Results.Conflict(new{loi="Giờ hẹn đã thay đổi, cần kiểm tra lại."});
            if(await db.YeuCauHuyHopDong.AnyAsync(x=>x.MaHopDong==id&&x.TrangThai=="CHO_XAC_NHAN",ct))return Results.Conflict(new{loi="Đã có yêu cầu cần xử lý."});
            var ready=request.KhongCoLichHenMoi&&request.CuaHangSanSang&&request.KhachChuaDen&&request.DaThuLienHe
                &&await hours.IsOpenAsync(h.MaCuaHang,DateTime.UtcNow,ct)&&await hours.IsOpenAsync(h.MaCuaHang,RentalPolicy.Utc(h.ThoiGianBanGiao),ct);
            var row=new YeuCauHuyHopDong{Id=ApiAccess.NewId("YH"),MaHopDong=id,LoaiYeuCau="KHONG_DEN",YeuCauLucUtc=DateTime.UtcNow,
                LyDo=request.GhiChu.Trim(),BangChung=JsonSerializer.Serialize(request),CanAdminXuLy=!ready||request.CoTranhChap||request.DeNghiNgoaiLe,TyLeKhauTru=1m};
            db.YeuCauHuyHopDong.Add(row);
            db.NhatKyNghiepVu.Add(new(){Id=ApiAccess.NewId("AU"),HanhDong="NO_SHOW_EVIDENCE",DoiTuongId=id,MaTaiKhoan=ApiAccess.AccountId(principal)!,
                ThoiGianUtc=DateTime.UtcNow,LyDo=row.LyDo,DuLieuJson=row.BangChung});
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Created("/api/hop-dong/"+id+"/huy-truoc-ban-giao",row);
        }).RequireAuthorization("Staff");
        app.MapPost("/api/yeu-cau-huy/{id}/de-nghi-ngoai-le",async(string id,ExceptionProposal request,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            if(string.IsNullOrWhiteSpace(request.LyDo)||request.LyDo.Length>500)return Results.BadRequest();
            var parent=await db.YeuCauHuyHopDong.Where(x=>x.Id==id).Select(x=>x.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            var row=await db.YeuCauHuyHopDong.SingleAsync(x=>x.Id==id,ct);if(row.TrangThai!="CHO_XAC_NHAN")return Results.Conflict();
            row.CanAdminXuLy=true;
            db.NhatKyNghiepVu.Add(new(){Id=ApiAccess.NewId("AU"),HanhDong="CANCELLATION_EXCEPTION_PROPOSED",DoiTuongId=id,MaTaiKhoan=ApiAccess.AccountId(principal)!,
                ThoiGianUtc=DateTime.UtcNow,LyDo=request.LyDo,DuLieuJson=JsonSerializer.Serialize(request)});
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(new{row.Id,row.CanAdminXuLy});
        }).RequireAuthorization("Staff");
    }
}
public sealed record NoShowEvidence(DateTime GioHenDaXacNhan,bool KhongCoLichHenMoi,bool CuaHangSanSang,bool KhachChuaDen,bool DaThuLienHe,
    DateTime LienHeLucUtc,string KenhLienHe,string KetQuaLienHe,string GhiChu,string? TaiLieuUrl,bool CoTranhChap,bool DeNghiNgoaiLe);
public sealed record ExceptionProposal(string LyDo,string? TaiLieuUrl);
