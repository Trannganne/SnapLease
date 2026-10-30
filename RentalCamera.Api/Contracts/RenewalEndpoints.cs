using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Email;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Contracts;

public static class RenewalEndpoints
{
    public static readonly string[] ActiveStates=["CHO_XAC_NHAN","CHO_KY"];
    public static bool Effective(PhuLuc p) => p.TrangThai is "DA_XAC_NHAN" or "DA_HIEU_LUC";
    public static async Task<DateTime> EffectiveReturnAsync(HopDong contract,RentalCameraContext db,CancellationToken ct) {
        var date=await db.PhuLuc.Where(p=>p.MaHopDong==contract.MaHopDong && (p.TrangThai=="DA_XAC_NHAN" || p.TrangThai=="DA_HIEU_LUC"))
            .MaxAsync(p=>(DateTime?)p.ThoiHanTraMoi,ct);
        return date.HasValue && date.Value>contract.ThoiGianTraDuKien?date.Value:contract.ThoiGianTraDuKien;
    }
    public static async Task ExpireAsync(string contractId,RentalCameraContext db,CancellationToken ct) {
        if(RentalPolicy.ProtectedContracts.Contains(contractId))return;
        var now=DateTime.UtcNow;
        var rows=await db.PhuLuc.Where(p=>p.MaHopDong==contractId &&
            (p.TrangThai=="CHO_XAC_NHAN" && p.HanXuLyUtc<=now || p.TrangThai=="CHO_KY" && p.HanKyUtc<=now)).ToListAsync(ct);
        foreach(var p in rows)p.TrangThai=p.TrangThai=="CHO_XAC_NHAN"?"HET_HAN_XU_LY":"HET_HAN_KY";
        if(rows.Count>0)await db.SaveChangesAsync(ct);
    }

    public static void MapRenewalEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/gia-han/{id}/dong-quy-trinh-cu",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            var parent=await db.PhuLuc.AsNoTracking().Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);
            if(parent is null)return Results.NotFound();
            if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict(new{loi="Hồ sơ liên quan hợp đồng bảo toàn; chỉ báo cáo, giữ nguyên."});
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
            if(p.TrangThai=="DONG_QUY_TRINH_CU")return Results.Ok(Dto(p));
            if(!LegacyPending(p))return Results.Conflict(new{loi="Chỉ đóng hồ sơ chờ theo quy trình cũ chưa đủ dữ liệu."});
            var before=JsonSerializer.Serialize(Dto(p));
            p.TrangThai="DONG_QUY_TRINH_CU";p.NguoiXuLy=ApiAccess.AccountId(principal);p.DongLucUtc=DateTime.UtcNow;
            p.LyDoDong="Yêu cầu theo quy trình cũ, chưa đủ dữ liệu để tiếp tục quy trình mới";

            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(Dto(p));
        }).RequireAuthorization("Admin");
        app.MapGet("/api/hop-dong/{id}/du-kien-gia-han", async (string id,DateTime thoiHanTraMoi,ClaimsPrincipal principal,
            RentalCameraContext db,AvailabilityService availability,BranchWorkingHours hours,CancellationToken ct) => {
            var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
            var contract=await db.HopDong.AsNoTracking().SingleOrDefaultAsync(h=>h.MaHopDong==id && h.MaKhachThue==customer,ct);
            if(contract is null)return Results.NotFound();
            var quote=await QuoteAsync(contract,thoiHanTraMoi,db,availability,hours,ct);
            return quote.CoTheGiaHan?Results.Ok(quote):Results.Conflict(quote);
        }).RequireAuthorization("Customer");
        app.MapPost("/api/hop-dong/{id}/yeu-cau-gia-han",async (string id,ExtensionRequest request,ClaimsPrincipal principal,
            RentalCameraContext db,AvailabilityService availability,BranchWorkingHours hours,ContractSignatureService signature,CancellationToken ct) => {
            if(string.IsNullOrWhiteSpace(request.LyDoGiaHan)||request.LyDoGiaHan.Trim().Length>500)return Results.BadRequest(new{loi="Lý do bắt buộc, tối đa 500 ký tự."});
            var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var contract=await db.HopDong.SingleOrDefaultAsync(h=>h.MaHopDong==id && h.MaKhachThue==customer,ct);
            if(contract is null)return Results.NotFound();
            await ExpireAsync(id,db,ct);
            if(await db.PhuLuc.AnyAsync(p=>p.MaHopDong==id && ActiveStates.Contains(p.TrangThai),ct)){await tx.CommitAsync(ct);return Results.Conflict(new{loi="Đã có yêu cầu gia hạn đang hoạt động."});}
            var quote=await QuoteAsync(contract,request.ThoiHanTraMoi,db,availability,hours,ct);
            if(!quote.CoTheGiaHan){await tx.CommitAsync(ct);return Results.Conflict(quote);}
            var deadline=(await hours.AddWorkingHoursUtcAsync(contract.MaCuaHang,DateTime.UtcNow,4,ct))!.Value;
            var cutoff=RentalPolicy.Utc(quote.ThoiHanTraHienTai).AddHours(-2);
            var p=new PhuLuc{MaPhuLuc=ApiAccess.NewId("PL"),MaHopDong=id,NgayLap=DateTime.UtcNow,TrangThai="CHO_XAC_NHAN",
                HieuLucTu=quote.ThoiHanTraHienTai,ThoiHanTraMoi=request.ThoiHanTraMoi,ChiPhiPhatSinh=quote.ChiPhiDuKien,
                LyDoGiaHan=request.LyDoGiaHan.Trim(),GhiChu=request.GhiChu?.Trim(),HanXuLyUtc=deadline<cutoff?deadline:cutoff,
                PhienBanDieuKhoan=RentalPolicy.TermsVersion};
            p.NoiDungJson=JsonSerializer.Serialize(new{p.MaPhuLuc,p.MaHopDong,p.HieuLucTu,p.ThoiHanTraMoi,p.ChiPhiPhatSinh,
                p.PhienBanDieuKhoan,phienBanHopDongGoc=contract.PhienBanDieuKhoan,soNgay=quote.SoNgayGiaHan,
                dieuKhoan=RentalPolicy.AppendixTerms(contract.PhienBanDieuKhoan),thanhToan="Quyết toán khi trả máy"});
            p.MaBamNoiDung=signature.HashContent(p.NoiDungJson);
            db.PhuLuc.Add(p);await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);
            return Results.Created("/api/gia-han/"+p.MaPhuLuc,Dto(p));
        }).RequireAuthorization("Customer");
        app.MapGet("/api/gia-han/cho-duyet",async(ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var expiredParents=await db.PhuLuc.AsNoTracking().Join(db.HopDong,p=>p.MaHopDong,h=>h.MaHopDong,(p,h)=>new{p,h})
                .Where(x=>(scope.IsAdmin||x.h.MaCuaHang==scope.StoreId)&&
                    (x.p.TrangThai=="CHO_XAC_NHAN"&&x.p.HanXuLyUtc<=DateTime.UtcNow||x.p.TrangThai=="CHO_KY"&&x.p.HanKyUtc<=DateTime.UtcNow))
                .Select(x=>x.h.MaHopDong).Distinct().ToListAsync(ct);
            foreach(var parent in expiredParents){
                await using var expiration=await db.Database.BeginTransactionAsync(ct);
                await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
                await ExpireAsync(parent,db,ct);await expiration.CommitAsync(ct);
                db.ChangeTracker.Clear();
            }
            var rows=await db.PhuLuc.AsNoTracking().Join(db.HopDong,p=>p.MaHopDong,h=>h.MaHopDong,(p,h)=>new{p,h})
                .Where(x=>x.p.TrangThai=="CHO_XAC_NHAN" && (scope.IsAdmin||x.h.MaCuaHang==scope.StoreId)).ToListAsync(ct);
            return Results.Ok(rows.Select(x=>Dto(x.p)));
        }).RequireAuthorization("Staff");
        app.MapPut("/api/gia-han/{id}/xu-ly",async(string id,ProcessExtensionRequest request,ClaimsPrincipal principal,
            RentalCameraContext db,AvailabilityService availability,CancellationToken ct)=> {
            if(request.QuyetDinh is not("DUYET" or "TU_CHOI") || string.IsNullOrWhiteSpace(request.GhiChu)||request.GhiChu.Trim().Length>500)return Results.BadRequest(new{loi="Quyết định và lý do xử lý là bắt buộc."});
            var scope=await ApiAccess.StaffScopeAsync(principal,db,ct);if(scope is null)return Results.Forbid();
            var parent=await db.PhuLuc.AsNoTracking().Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);
            if(parent is null)return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);
            if(!scope.IsAdmin&&h.MaCuaHang!=scope.StoreId)return Results.Forbid();
            if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            await ExpireAsync(parent,db,ct);
            var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
            if(p.TrangThai!="CHO_XAC_NHAN" || p.HanXuLyUtc is null){await tx.CommitAsync(ct);return Results.Conflict(new{loi="Yêu cầu hết hạn/đã xử lý hoặc thiếu deadline legacy."});}
            if(request.QuyetDinh=="DUYET") {
                if(h.TrangThai!="DANG_THUE"||await db.ChiTietHopDong.AnyAsync(d=>d.MaHopDong==parent && d.NgayNhanThucTe!=null,ct))return Results.Conflict(new{loi="Hợp đồng không còn đang thuê đầy đủ."});
                if(p.HieuLucTu!=await EffectiveReturnAsync(h,db,ct)||!await AvailableAsync(h,p.HieuLucTu.Value,p.ThoiHanTraMoi,db,availability,ct))return Results.Conflict(new{loi="Lịch/thiết bị thực tế đã thay đổi."});
                p.TrangThai="CHO_KY";p.DuyetLucUtc=DateTime.UtcNow;p.HanKyUtc=RentalPolicy.SigningDeadline(DateTime.UtcNow,p.HieuLucTu.Value);
            } else p.TrangThai="TU_CHOI";
            p.NguoiXuLy=ApiAccess.AccountId(principal);p.GhiChu=request.GhiChu.Trim();
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(Dto(p));
        }).RequireAuthorization("Staff");

        app.MapGet("/api/gia-han/{id}",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            var p=await db.PhuLuc.AsNoTracking().SingleOrDefaultAsync(p=>p.MaPhuLuc==id,ct);
            if(p is null)return Results.NotFound();if(!await ApiAccess.CanAccessContractAsync(p.MaHopDong,principal,db,ct))return Results.Forbid();
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+p.MaHopDong,ct);
            await ExpireAsync(p.MaHopDong,db,ct);await tx.CommitAsync(ct);
            p=await db.PhuLuc.AsNoTracking().SingleAsync(p=>p.MaPhuLuc==id,ct);return Results.Ok(Dto(p));
        }).RequireAuthorization();
        app.MapPut("/api/gia-han/{id}/tep-pdf",async(string id,HttpRequest request,ClaimsPrincipal principal,RentalCameraContext db,ContractPdfService pdf,CancellationToken ct)=> {
            var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
            var parent=await db.PhuLuc.Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);
            if(parent is null)return Results.NotFound();
            if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict();
            await using var tx=await db.Database.BeginTransactionAsync(ct);
            await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(h.MaKhachThue!=customer)return Results.Forbid();
            await ExpireAsync(parent,db,ct);var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
            if(p.TrangThai!="CHO_KY"||p.MaBamTepPdf!=null){await tx.CommitAsync(ct);return Results.Conflict(new{loi="Phụ lục chưa chờ ký hoặc PDF đã cố định."});}
            try{var result=await pdf.SaveAsync("appendix-"+id,request.Body,ct);p.MaBamTepPdf=result.Sha256;}
            catch(InvalidDataException ex){return Results.BadRequest(new{loi=ex.Message});}
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(Dto(p));
        }).RequireAuthorization("Customer");
        app.MapGet("/api/gia-han/{id}/tep-pdf",async(string id,ClaimsPrincipal principal,RentalCameraContext db,ContractPdfService pdf,CancellationToken ct)=> {
            var p=await db.PhuLuc.AsNoTracking().SingleOrDefaultAsync(p=>p.MaPhuLuc==id,ct);
            if(p is null)return Results.NotFound();if(!await ApiAccess.CanAccessContractAsync(p.MaHopDong,principal,db,ct))return Results.Forbid();
            if(p.MaBamTepPdf is null || !await pdf.VerifyAsync("appendix-"+id,p.MaBamTepPdf,ct))return Results.NotFound();
            return Results.File(pdf.OpenRead("appendix-"+id),"application/pdf");
        }).RequireAuthorization();
        app.MapPost("/api/gia-han/{id}/yeu-cau-ky",RequestSignatureAsync).RequireAuthorization("Customer");
        app.MapPut("/api/gia-han/{id}/ky",SignAsync).RequireAuthorization("Customer");
        app.MapPost("/api/gia-han/{id}/huy",async(string id,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=> {
            var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
            var parent=await db.PhuLuc.Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
            if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict();
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(h.MaKhachThue!=customer)return Results.Forbid();
            await ExpireAsync(parent,db,ct);var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
            if(!ActiveStates.Contains(p.TrangThai)){await tx.CommitAsync(ct);return Results.Conflict();}
            p.TrangThai="DA_HUY";await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(Dto(p));
        }).RequireAuthorization("Customer");
    }

    private static async Task<IResult> RequestSignatureAsync(string id,ClaimsPrincipal principal,RentalCameraContext db,ContractSignatureService signature,ContractPdfService pdf,
        [FromKeyedServices(ContractSigningOtpRegistration.ServiceKey)] IContractOtpEmailSender email,CancellationToken ct)
    {
        if(!email.IsConfigured)return Results.Problem("Chưa cấu hình email OTP.",statusCode:503);
        var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
        var parent=await db.PhuLuc.Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
        if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict();
        await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
        var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(h.MaKhachThue!=customer)return Results.Forbid();
        await ExpireAsync(parent,db,ct);var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
        if(p.TrangThai!="CHO_KY"||p.MaBamTepPdf is null||!await pdf.VerifyAsync("appendix-"+id,p.MaBamTepPdf,ct)){await tx.CommitAsync(ct);return Results.Conflict(new{loi="Phụ lục không có PDF hợp lệ đang chờ ký."});}
        if(p.OtpGuiLucUtc>DateTime.UtcNow.AddSeconds(-60))return Results.Conflict(new{loi="Đợi 60 giây trước khi gửi lại OTP."});
        if(p.SoLanGuiOtp>=5||p.SoLanThuOtp>=5)return Results.Conflict(new{loi="Đã hết lượt gửi/thử OTP cho phụ lục này."});
        var recipient=await db.KhachThue.SingleAsync(k=>k.MaKhachThue==customer,ct);if(string.IsNullOrWhiteSpace(recipient.Email))return Results.BadRequest(new{loi="Thiếu email nhận OTP."});
        var otp=signature.GenerateOtp();var hashed=signature.HashOtp(otp);p.MaOtpHash=hashed.Hash;p.MuoiOtp=hashed.Salt;p.SoLanGuiOtp++;
        p.MaXacNhanKy=ApiAccess.NewId("XP");p.OtpGuiLucUtc=DateTime.UtcNow;
        if(p.HanKyUtc is not DateTime signingDeadline)return Results.Conflict(new{loi="Thiếu hạn ký."});
        p.OtpHetHanUtc=DateTime.UtcNow.AddMinutes(5)<signingDeadline?DateTime.UtcNow.AddMinutes(5):signingDeadline;
        // Commit only when the email provider accepted the OTP; no OTP ever returned/logged.
        try { await email.SendAsync(recipient.Email,recipient.HoTen??"khách hàng","phụ lục "+id,otp,p.OtpHetHanUtc.Value,ct); }
        catch { return Results.Problem("Chưa gửi được OTP, hãy thử lại sau.",statusCode:503); }
        await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);
        return Results.Ok(new{maXacNhan=p.MaXacNhanKy,hetHanLuc=p.OtpHetHanUtc,maBamNoiDung=p.MaBamNoiDung,maBamTepPdf=p.MaBamTepPdf});
    }
    private static async Task<IResult> SignAsync(string id,AppendixSignRequest request,ClaimsPrincipal principal,HttpContext http,RentalCameraContext db,ContractSignatureService signature,ContractPdfService pdf,AvailabilityService availability,CancellationToken ct)
    {
        if(!request.DaDongYDieuKhoan||request.MaOtp?.Length!=6)return Results.BadRequest();
        var customer=await ApiAccess.CustomerIdAsync(principal,db,ct);
        var parent=await db.PhuLuc.Where(p=>p.MaPhuLuc==id).Select(p=>p.MaHopDong).SingleOrDefaultAsync(ct);if(parent is null)return Results.NotFound();
        if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict();
        await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
        var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==parent,ct);if(h.MaKhachThue!=customer)return Results.Forbid();
        await ExpireAsync(parent,db,ct);var p=await db.PhuLuc.SingleAsync(p=>p.MaPhuLuc==id,ct);
        if(p.TrangThai=="DA_HIEU_LUC")return Results.Ok(Dto(p));
        if(p.TrangThai!="CHO_KY"||h.TrangThai!="DANG_THUE"||p.MaXacNhanKy!=request.MaXacNhan||p.OtpHetHanUtc is null||p.OtpHetHanUtc<=DateTime.UtcNow||p.SoLanThuOtp>=5||p.MaOtpHash is null||p.MuoiOtp is null){await tx.CommitAsync(ct);return Results.Conflict(new{loi="OTP/phụ lục hết hạn hoặc trạng thái đã thay đổi."});}
        if(p.MaBamNoiDung!=request.MaBamNoiDung||p.MaBamTepPdf is null||!await pdf.VerifyAsync("appendix-"+id,p.MaBamTepPdf,ct))return Results.Conflict(new{loi="Nội dung/PDF không khớp yêu cầu ký."});
        p.SoLanThuOtp++;
        if(!signature.VerifyOtp(request.MaOtp,p.MaOtpHash,p.MuoiOtp)){await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.BadRequest(new{loi="OTP không đúng."});}
        if(p.HieuLucTu!=await EffectiveReturnAsync(h,db,ct)||!await AvailableAsync(h,p.HieuLucTu!.Value,p.ThoiHanTraMoi,db,availability,ct))return Results.Conflict(new{loi="Lịch/thiết bị đã thay đổi, chưa thể ký."});
        p.TrangThai="DA_HIEU_LUC";p.KyLucUtc=DateTime.UtcNow;p.DiaChiIpKy=http.Connection.RemoteIpAddress?.ToString();
        p.MaOtpHash=null;p.MuoiOtp=null;
        await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(Dto(p));
    }
    private static async Task<ExtensionQuote> QuoteAsync(HopDong h,DateTime to,RentalCameraContext db,AvailabilityService availability,BranchWorkingHours hours,CancellationToken ct)
    {
        var current=await EffectiveReturnAsync(h,db,ct);
        ExtensionQuote No(string reason)=>new(false,reason,current,to,0,0);
        if(RentalPolicy.ProtectedContracts.Contains(h.MaHopDong))return No("Hợp đồng được bảo toàn.");
        if(!RentalPolicy.CanUseExtensionTerms(h.PhienBanDieuKhoan,h.DaDongYDieuKhoan))return No("Cần cửa hàng kiểm tra điều khoản/bằng chứng đã ký trước khi báo giá gia hạn; không tự áp chính sách mới lên hồ sơ chưa xác định.");
        if(!RentalPolicy.CanRequestExtension(new(h.TrangThai,current,await db.ChiTietHopDong.AnyAsync(d=>d.MaHopDong==h.MaHopDong&&d.NgayNhanThucTe!=null,ct)),DateTime.UtcNow))return No("Chỉ gia hạn khi đang thuê và trước hạn trả ít nhất 24 giờ.");
        if(to.Kind!=DateTimeKind.Unspecified||to<=current||to-current>TimeSpan.FromDays(90))return No("Hạn mới không hợp lệ; dùng giờ Việt Nam không kèm múi giờ.");
        if(await hours.AddWorkingHoursUtcAsync(h.MaCuaHang,DateTime.UtcNow,4,ct) is null)return No("Chưa có lịch làm việc chi nhánh được xác nhận.");
        if(!await AvailableAsync(h,current,to,db,availability,ct))return No("Thiết bị/serial thực tế không còn khả dụng cho toàn bộ thời gian gia hạn.");
        var daily=await db.ChiTietHopDong.Where(d=>d.MaHopDong==h.MaHopDong).SumAsync(d=>(decimal?)d.DonGia,ct)??0;
        if(daily<=0)return No("Không xác định được đơn giá gốc.");
        var days=(int)Math.Ceiling((to-current).TotalDays);return new(true,null,current,to,days,Math.Round(days*daily,2));
    }
    private static async Task<bool> AvailableAsync(HopDong h,DateTime from,DateTime to,RentalCameraContext db,AvailabilityService availability,CancellationToken ct)
    {
        var actual=await db.ChiTietHopDong.Where(d=>d.MaHopDong==h.MaHopDong).Join(db.ThietBi,d=>d.MaThietBi,t=>t.MaThietBi,(d,t)=>new{d,t}).ToListAsync(ct);
        if(actual.Count==0||actual.Any(x=>x.d.NgayGiaoThucTe==null||x.d.NgayNhanThucTe!=null))return false;
        foreach(var group in actual.GroupBy(x=>x.t.MaDongMay).OrderBy(x=>x.Key))
            if(await availability.GetAvailableAsync(h.MaCuaHang,group.Key,from,to,null,h.MaHopDong,ct)<group.Count())return false;
        var deviceIds=actual.Select(x=>x.d.MaThietBi).ToArray();
        var conflicts=await db.ChiTietHopDong.Where(d=>deviceIds.Contains(d.MaThietBi)&&d.MaHopDong!=h.MaHopDong&&d.NgayNhanThucTe==null)
            .Join(db.HopDong,d=>d.MaHopDong,c=>c.MaHopDong,(d,c)=>c).Where(c=>c.TrangThai=="CHO_KY"||c.TrangThai=="DA_KY"||c.TrangThai=="CHO_BAN_GIAO"||c.TrangThai=="DANG_THUE"||c.TrangThai=="CHO_HOAN_TRA").ToListAsync(ct);
        foreach(var other in conflicts) {
            var signed=await EffectiveReturnAsync(other,db,ct);
            var held=await db.PhuLuc.Where(p=>p.MaHopDong==other.MaHopDong&&p.TrangThai=="CHO_KY"&&p.HanKyUtc>DateTime.UtcNow)
                .MaxAsync(p=>(DateTime?)p.ThoiHanTraMoi,ct);
            var reservedDue=held.HasValue&&held.Value>signed?held.Value:signed;
            if(other.ThoiGianBanGiao<to && reservedDue>from)return false;
        }
        return true;
    }
    private static DateTime? UtcDate(DateTime? value)=>value.HasValue?DateTime.SpecifyKind(value.Value,DateTimeKind.Utc):null;
    public static object Dto(PhuLuc p)=>new {p.MaPhuLuc,p.MaHopDong,ngayLap=p.PhienBanDieuKhoan==RentalPolicy.TermsVersion?DateTime.SpecifyKind(p.NgayLap,DateTimeKind.Utc):p.NgayLap,
        p.TrangThai,p.ThoiHanTraMoi,p.HieuLucTu,p.ChiPhiPhatSinh,p.TienCocBoSung,p.LyDoGiaHan,p.GhiChu,p.LyDoDong,p.NguoiXuLy,
        hanXuLyUtc=UtcDate(p.HanXuLyUtc),hanKyUtc=UtcDate(p.HanKyUtc),duyetLucUtc=UtcDate(p.DuyetLucUtc),kyLucUtc=UtcDate(p.KyLucUtc),dongLucUtc=UtcDate(p.DongLucUtc),
        p.PhienBanDieuKhoan,p.NoiDungJson,p.MaBamNoiDung,p.MaBamTepPdf,muiGioThue="Asia/Ho_Chi_Minh"};
    public static bool LegacyPending(PhuLuc p)=>p.TrangThai=="CHO_XAC_NHAN"&&p.PhienBanDieuKhoan!=RentalPolicy.TermsVersion&&p.HanXuLyUtc is null&&p.KyLucUtc is null;
}
public sealed record AppendixSignRequest(string MaXacNhan,string MaOtp,string MaBamNoiDung,bool DaDongYDieuKhoan);
