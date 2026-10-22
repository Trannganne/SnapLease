using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;
public static class ReturnTimeCorrectionEndpoints
{
    public static void MapReturnTimeCorrectionEndpoints(this IEndpointRouteBuilder app)=>app.MapPut("/api/chi-tiet-hop-dong/{id}/thoi-gian-nhan",async(string id,ReturnTimeCorrection request,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
        var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
        if(string.IsNullOrWhiteSpace(request.LyDo)||request.LyDo.Length>500||request.NgayNhanThucTe.Kind!=DateTimeKind.Unspecified||request.NgayNhanThucTe>RentalPolicy.LocalNow)return Results.BadRequest();
        var parent=await db.ChiTietHopDong.Where(d=>d.MaChiTietHopDong==id).Select(d=>d.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
        await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
        var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
        if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
        var d=await db.ChiTietHopDong.SingleAsync(d=>d.MaChiTietHopDong==id,ct);
        if(d.NgayNhanThucTe is null||request.NgayNhanThucTe<d.NgayGiaoThucTe)return Results.Conflict();
        var before=d.NgayNhanThucTe;d.NgayNhanThucTe=request.NgayNhanThucTe;
        db.NhatKyNghiepVu.Add(new(){Id=ApiAccess.NewId("AU"),HanhDong="RETURN_TIME_CORRECTED",DoiTuongId=id,MaTaiKhoan=ApiAccess.AccountId(principal)!,
            ThoiGianUtc=DateTime.UtcNow,LyDo=request.LyDo.Trim(),DuLieuJson=JsonSerializer.Serialize(new{before,after=d.NgayNhanThucTe,doiSoatSauQuyetToan=h.TrangThai=="HOAN_THANH"})});
        await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(new{d.MaChiTietHopDong,d.NgayNhanThucTe,canDoiSoatDaQuyetToan=h.TrangThai=="HOAN_THANH"});
    }).RequireAuthorization("Staff");
}
public sealed record ReturnTimeCorrection(DateTime NgayNhanThucTe,string LyDo);
