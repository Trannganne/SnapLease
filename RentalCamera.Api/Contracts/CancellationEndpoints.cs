using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public static class CancellationEndpoints
{
    public static void MapCancellationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/yeu-cau-huy/cho-duyet",async(ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var rows=await db.YeuCauHuyHopDong.AsNoTracking().Join(db.HopDong,r=>r.MaHopDong,h=>h.MaHopDong,(r,h)=>new{r,h.MaCuaHang})
                .Where(x=>x.r.TrangThai=="CHO_XAC_NHAN"&&(scope.IsAdmin||x.MaCuaHang==scope.StoreId))
                .OrderBy(x=>x.r.YeuCauLucUtc).Select(x=>new{x.MaCuaHang,yeuCau=x.r}).ToListAsync(ct);
            return Results.Ok(rows);
        }).RequireAuthorization("Staff");
        app.MapGet("/api/yeu-cau-huy/{id}/ho-so",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var row=await db.YeuCauHuyHopDong.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct);if(row is null)return Results.NotFound();
            var store=await db.HopDong.Where(h=>h.MaHopDong==row.MaHopDong).Select(h=>h.MaCuaHang).SingleAsync(ct);
            if(!scope.IsAdmin&&store!=scope.StoreId)return Results.Forbid();
            var payments=await db.ThanhToan.AsNoTracking().Where(p=>p.MaYeuCauHuy==id).ToListAsync(ct);
            var paymentIds=payments.Select(p=>p.MaThanhToan).ToArray();
            return Results.Ok(new{yeuCau=row,hoanTien=payments,
                lichSu=await db.NhatKyNghiepVu.AsNoTracking().Where(a=>a.DoiTuongId==id||a.DoiTuongId==row.MaHopDong).OrderBy(a=>a.ThoiGianUtc).ToListAsync(ct),
                chungTuHoan=await db.HoanTienAudit.AsNoTracking().Where(a=>paymentIds.Contains(a.MaThanhToan)).OrderBy(a=>a.ThoiGianUtc).ToListAsync(ct)});
        }).RequireAuthorization("Staff");
        app.MapGet("/api/hop-dong/{id}/huy-truoc-ban-giao",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            if(!await ApiAccess.CanAccessContractAsync(id,principal,db,ct))return Results.Forbid();
            var rows=await db.YeuCauHuyHopDong.AsNoTracking().Where(x=>x.MaHopDong==id).OrderByDescending(x=>x.YeuCauLucUtc)
                .Select(x=>new{x.Id,x.MaHopDong,x.LoaiYeuCau,x.TrangThai,x.YeuCauLucUtc,x.LyDo,x.XuLyLucUtc,x.LyDoXuLy,
                    x.MienKhauTru,x.TyLeKhauTru,x.TienCocDaThu,x.TienThueDaThu,x.TienThuThuaDaThu,x.TienKhauTru,
                    x.TienCocPhaiHoan,x.TienThuePhaiHoan,x.TienThuThuaPhaiHoan}).ToListAsync(ct);
            var refunds=await db.ThanhToan.AsNoTracking().Where(x=>x.MaHopDong==id&&x.MaYeuCauHuy!=null).Select(x=>new{x.MaThanhToan,x.SoTien,x.LoaiThanhToan,x.TrangThai,x.MaGiaoDich,x.ThoiGian}).ToListAsync(ct);
            return Results.Ok(new{yeuCau=rows,hoanTien=refunds});
        }).RequireAuthorization();
        app.MapPost("/api/hop-dong/{id}/huy-truoc-ban-giao",async(string id,CancellationRequest request,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            if(string.IsNullOrWhiteSpace(request.LyDo)||request.LyDo.Trim().Length>500)return Results.BadRequest(new{loi="Lý do hủy bắt buộc, tối đa 500 ký tự."});
            var requested=DateTime.UtcNow;var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var h=await db.HopDong.SingleOrDefaultAsync(h=>h.MaHopDong==id&&h.MaKhachThue==customer,ct);if(h is null)return Results.NotFound();
            if(!await EligibleAsync(h,db,ct))return Results.Conflict(new{loi="Chỉ yêu cầu hủy hợp đồng DA_KY/CHO_BAN_GIAO chưa bàn giao, có phiên bản chính sách mới được chấp thuận."});
            var existing=await db.YeuCauHuyHopDong.SingleOrDefaultAsync(x=>x.MaHopDong==id&&x.TrangThai=="CHO_XAC_NHAN",ct);
            if(existing is not null)return Results.Ok(existing);
            var row=new YeuCauHuyHopDong{Id=ApiAccess.NewId("YH"),MaHopDong=id,YeuCauLucUtc=requested,LyDo=request.LyDo.Trim(),
                TyLeKhauTru=RentalPolicy.CancellationRate(h.ThoiGianBanGiao,DateTime.SpecifyKind(requested.AddHours(7),DateTimeKind.Unspecified))};
            await ReconcileAsync(row,db,ct,false);db.YeuCauHuyHopDong.Add(row);
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Created("/api/hop-dong/"+id+"/huy-truoc-ban-giao",row);
        }).RequireAuthorization("Customer");
        app.MapPut("/api/yeu-cau-huy/{id}/xu-ly",async(string id,ProcessCancellationRequest request,ClaimsPrincipal principal,RentalCameraContext db,IConfiguration config,CancellationToken ct)=> {
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            if(request.MienKhauTru&&!scope.IsAdmin)return Results.Forbid();
            if(request.QuyetDinh is not("DUYET" or "TU_CHOI")||string.IsNullOrWhiteSpace(request.LyDo)||request.LyDo.Trim().Length>500)return Results.BadRequest();
            var parent=await db.YeuCauHuyHopDong.Where(x=>x.Id==id).Select(x=>x.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var row=await db.YeuCauHuyHopDong.SingleAsync(x=>x.Id==id,ct);var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);
            var before=System.Text.Json.JsonSerializer.Serialize(row);
            if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            if(row.CanAdminXuLy&&!scope.IsAdmin)return Results.Forbid();
            if(row.TrangThai!="CHO_XAC_NHAN")return Results.Ok(row);
            if(!await EligibleAsync(h,db,ct))return Results.Conflict(new{loi="Hợp đồng đã bàn giao/đổi trạng thái; không thể hủy trước bàn giao."});
            row.NguoiXuLy=ApiAccess.AccountId(principal);row.XuLyLucUtc=DateTime.UtcNow;row.LyDoXuLy=request.LyDo.Trim();
            if(request.QuyetDinh=="TU_CHOI")row.TrangThai="TU_CHOI";
            else {
                row.MienKhauTru=request.MienKhauTru;
                if(request.MienKhauTru && request.CanCuNgoaiLe is not("BAT_KHA_KHANG" or "LOI_CUA_HANG"))return Results.BadRequest(new{loi="Miễn khấu trừ cần căn cứ bất khả kháng hoặc lỗi cửa hàng đã xác nhận."});
                row.LyDoXuLy+=(request.MienKhauTru?"; "+request.CanCuNgoaiLe:"");
                row.TrangThai="DA_DUYET";h.TrangThai="DA_HUY";
                // Device allocations are retained as history; contract state releases their schedule.
                var allocated=await db.ChiTietHopDong.Where(d=>d.MaHopDong==parent).Select(d=>d.MaThietBi).ToListAsync(ct);
                var devices=await db.ThietBi.Where(t=>allocated.Contains(t.MaThietBi)&&t.TrangThai=="DANG_GIU").ToListAsync(ct);
                foreach(var device in devices)device.TrangThai="SAN_SANG";
                await ReconcileAsync(row,db,ct,true);
            }
            db.NhatKyNghiepVu.Add(new(){Id=ApiAccess.NewId("AU"),HanhDong="CANCELLATION_"+request.QuyetDinh,
                DoiTuongId=row.Id,MaTaiKhoan=ApiAccess.AccountId(principal)!,ThoiGianUtc=DateTime.UtcNow,
                LyDo=request.LyDo.Trim(),DuLieuJson=System.Text.Json.JsonSerializer.Serialize(new{before,after=row,request.CanCuNgoaiLe})});
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(row);
        }).RequireAuthorization("Staff");
        app.MapPost("/api/yeu-cau-huy/{id}/doi-soat",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var parent=await db.YeuCauHuyHopDong.Where(x=>x.Id==id).Select(x=>x.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            var row=await db.YeuCauHuyHopDong.SingleAsync(x=>x.Id==id,ct);if(row.TrangThai!="DA_DUYET")return Results.Conflict();
            await ReconcileAsync(row,db,ct,true);await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(row);
        }).RequireAuthorization("Staff");
        app.MapPut("/api/thanh-toan/{id}/xac-nhan-hoan-huy",async(string id,RefundEvidenceRequest request,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            if(string.IsNullOrWhiteSpace(request.ChungTu)||request.ChungTu.Trim().Length>500)return Results.BadRequest(new{loi="Cần mã/chứng từ chuyển hoàn đã kiểm tra."});
            var parent=await db.ThanhToan.Where(x=>x.MaThanhToan==id).Select(x=>x.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            var p=await db.ThanhToan.SingleAsync(x=>x.MaThanhToan==id,ct);
            if(p.MaYeuCauHuy is null||h.TrangThai!="DA_HUY")return Results.Conflict();
            if(p.TrangThai=="DA_HOAN")return Results.Ok(new{p.MaThanhToan,p.TrangThai});
            if(p.TrangThai!="CHO_THANH_TOAN")return Results.Conflict();
            p.TrangThai="DA_HOAN";p.MaGiaoDich=request.ChungTu.Trim();p.ThoiGian=DateTime.UtcNow;
            db.HoanTienAudit.Add(new HoanTienAudit { Id=ApiAccess.NewId("AH"),MaThanhToan=p.MaThanhToan,
                MaTaiKhoan=ApiAccess.AccountId(principal)!,ChungTu=request.ChungTu.Trim(),ThoiGianUtc=DateTime.UtcNow });
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(new{p.MaThanhToan,p.TrangThai});
        }).RequireAuthorization("Staff");
    }
    internal static async Task<bool> EligibleAsync(HopDong h,RentalCameraContext db,CancellationToken ct)=>
        !RentalPolicy.ProtectedContracts.Contains(h.MaHopDong)&&h.TrangThai is "DA_KY" or "CHO_BAN_GIAO" && h.DaDongYDieuKhoan&&h.PhienBanDieuKhoan==RentalPolicy.TermsVersion&&
        !await db.ChiTietHopDong.AnyAsync(d=>d.MaHopDong==h.MaHopDong&&d.NgayGiaoThucTe!=null,ct);
    public static async Task ReconcileAsync(YeuCauHuyHopDong row,RentalCameraContext db,CancellationToken ct,bool createRefund)
    {
        var payments=await db.ThanhToan.Where(p=>p.MaHopDong==row.MaHopDong).ToListAsync(ct);
        payments.AddRange(db.ThanhToan.Local.Where(p=>p.MaHopDong==row.MaHopDong && !payments.Contains(p)));
        var paymentIds=payments.Where(p=>!p.LoaiThanhToan.StartsWith("HOAN_")).Select(p=>p.MaThanhToan).ToArray();
        // Filter status in memory: the current callback may still be an unsaved tracked change.
        var attempts=await db.YeuCauThanhToanVnpay.Where(a=>paymentIds.Contains(a.MaThanhToan)).ToListAsync(ct);
        row.TienCocDaThu=payments.Where(p=>p.LoaiThanhToan=="TIEN_COC"&&p.TrangThai=="THANH_CONG").Sum(p=>p.SoTien);
        row.TienThueDaThu=payments.Where(p=>p.LoaiThanhToan=="TIEN_THUE"&&p.TrangThai=="THANH_CONG").Sum(p=>p.SoTien);
        row.TienThuThuaDaThu=attempts.Where(a=>a.LaThuThua&&a.TrangThai=="THANH_CONG").Sum(a=>a.SoTien);
        var amounts=Amounts(row.TienCocDaThu,row.TienThueDaThu,row.TienThuThuaDaThu,row.TyLeKhauTru,row.MienKhauTru);
        row.TienKhauTru=amounts.Deduction;row.TienCocPhaiHoan=amounts.DepositRefund;
        row.TienThuePhaiHoan=amounts.RentRefund;row.TienThuThuaPhaiHoan=amounts.ExcessRefund;
        if(!createRefund)return;
        foreach(var part in new[]{(Type:"HOAN_COC",Amount:row.TienCocPhaiHoan),(Type:"HOAN_TIEN_THUE",Amount:row.TienThuePhaiHoan),(Type:"HOAN_THU_THUA",Amount:row.TienThuThuaPhaiHoan)}) {
            var reserved=payments.Where(p=>p.LoaiThanhToan==part.Type && p.TrangThai is "CHO_THANH_TOAN" or "DA_HOAN" or "THANH_CONG").Sum(p=>p.SoTien);
            var amount=Math.Max(0,part.Amount-reserved);if(amount==0)continue;
            db.ThanhToan.Add(new ThanhToan{MaThanhToan=ApiAccess.NewId("TT"),MaHopDong=row.MaHopDong,MaYeuCauHuy=row.Id,
                LoaiThanhToan=part.Type,SoTien=amount,PhuongThuc="CHUYEN_KHOAN",TrangThai="CHO_THANH_TOAN",NoiDungChuyenKhoan="Theo dõi khoản phải hoàn sau hủy; chưa chuyển tiền."});
        }
    }
    public static (decimal Deduction,decimal DepositRefund,decimal RentRefund,decimal ExcessRefund) Amounts(
        decimal validDeposit,decimal prepaidRent,decimal excess,decimal rate,bool exception)
    {
        var deduction=Math.Round(validDeposit*(exception?0:rate),2);
        return(deduction,validDeposit-deduction,prepaidRent,excess);
    }
}
public sealed record CancellationRequest(string LyDo);
public sealed record ProcessCancellationRequest(string QuyetDinh,string LyDo,bool MienKhauTru,string? CanCuNgoaiLe);
public sealed record RefundEvidenceRequest(string ChungTu);
