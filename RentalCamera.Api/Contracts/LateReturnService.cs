using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public static class LateReturnService
{
    public static decimal Cost(DateTime due,DateTime actualOrEstimate,decimal originalDailyPrice)=>
        Math.Round(RentalPolicy.LateDays(due,actualOrEstimate)*originalDailyPrice,2);
    public static async Task<LateReturnQuote?> QuoteAsync(string contractId,RentalCameraContext db,CancellationToken ct)
    {
        var h=await db.HopDong.AsNoTracking().SingleOrDefaultAsync(h=>h.MaHopDong==contractId,ct);if(h is null)return null;
        var due=await RenewalEndpoints.EffectiveReturnAsync(h,db,ct);
        if(h.PhienBanDieuKhoan!=RentalPolicy.TermsVersion||!h.DaDongYDieuKhoan)return new(contractId,false,due,null,true,[],"Giữ nguyên điều khoản/ngoại lệ cũ; chưa tự áp công thức tài chính mới.");
        var details=await db.ChiTietHopDong.AsNoTracking().Where(d=>d.MaHopDong==contractId&&d.NgayGiaoThucTe!=null).ToListAsync(ct);
        var now=RentalPolicy.LocalNow;
        var rows=details.Select(d=>new LateDevice(d.MaChiTietHopDong,d.MaThietBi,d.DonGia,d.NgayNhanThucTe,
            RentalPolicy.LateDays(due,d.NgayNhanThucTe??now),Cost(due,d.NgayNhanThucTe??now,d.DonGia),d.NgayNhanThucTe is null)).ToArray();
        return new(contractId,true,due,rows.Sum(x=>x.SoTien),rows.Any(x=>x.LaDuKien),rows,null);
    }
    public static void MapLateReturnEndpoints(IEndpointRouteBuilder app)=>app.MapGet("/api/hop-dong/{id}/tien-tra-tre",async(string id,System.Security.Claims.ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
        if(!await ApiAccess.CanAccessContractAsync(id,principal,db,ct))return Results.Forbid();var quote=await QuoteAsync(id,db,ct);return quote is null?Results.NotFound():Results.Ok(quote);
    }).RequireAuthorization();
}
public sealed record LateDevice(string MaChiTietHopDong,string MaThietBi,decimal DonGiaGoc,DateTime? NgayNhanThucTe,int SoNgayTinhThem,decimal SoTien,bool LaDuKien);
public sealed record LateReturnQuote(string MaHopDong,bool ApDungChinhSachMoi,DateTime HanTraHieuLuc,decimal? TongTien,bool LaDuKien,LateDevice[] ChiTiet,string? LyDo);
