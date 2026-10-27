using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Settlement;

namespace RentalCamera.Api.Handover;

public static class ReturnWorkflow
{
    public static async Task<IResult> ReceiveAsync(string id, ReturnRequest request, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope is null) return Results.Forbid();
        if (RentalPolicy.ProtectedContracts.Contains(id) || string.IsNullOrWhiteSpace(request.OperationId) || request.OperationId.Length > 100) return Results.Conflict(new { loi = "Cần mã thao tác hợp lệ; không nhận trả hợp đồng bảo toàn." });
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
        var h = await db.HopDong.SingleOrDefaultAsync(h => h.MaHopDong == id, ct); if (h is null) return Results.NotFound();
        if (!scope.IsAdmin && scope.StoreId != h.MaCuaHang) return Results.Forbid();
        var actor = ApiAccess.AccountId(p)!;
        var hash = SettlementJson.Hash(SettlementJson.Write(new { id, actor, request }));
        var key = await db.IdempotencyKey.SingleOrDefaultAsync(k => k.IdempotencyKey == request.OperationId && k.MaKhachThue == h.MaKhachThue && k.LoaiThaoTac == "RETURN_ALL", ct);
        if (key != null) return key.PayloadHash == hash ? Results.Ok(new { h.MaHopDong, h.TrangThai, maBienBan = key.MaThucThe, doiSoat = true }) : Results.Conflict(new { loi = "Mã thao tác đã dùng cho nội dung khác." });
        if (h.TrangThai != "DANG_THUE") return Results.Conflict(new { loi = "Hợp đồng không ở trạng thái đang thuê." });
        var details = await db.ChiTietHopDong.Where(d => d.MaHopDong == id).ToListAsync(ct);
        if (request.ThietBi is null || request.ThietBi.Any(i => i is null || string.IsNullOrWhiteSpace(i.TinhTrang) || i.TinhTrang.Length > 500)) return Results.BadRequest();
        try { SettlementLedger.ValidateFullReturn(details.Select(d => d.MaChiTietHopDong), request.ThietBi.Select(i => i.MaChiTietHopDong)); }
        catch (InvalidOperationException ex) { return Results.BadRequest(new { loi = ex.Message }); }
        if (details.Any(d => d.NgayNhanThucTe != null || d.NgayGiaoThucTe is null || d.LoaiNgoaiLeNhanTra != null))
            return Results.Conflict(new { loi = "Hồ sơ đã trả một phần, chưa bàn giao hoặc có ngoại lệ; không tạo lịch sử nhận đủ giả." });
        var devices = await db.ThietBi.Where(t => details.Select(d => d.MaThietBi).Contains(t.MaThietBi)).OrderBy(t => t.MaThietBi).ToListAsync(ct);
        if (devices.Count != details.Count || details.Any(d => request.ThietBi.Single(i => i.MaChiTietHopDong == d.MaChiTietHopDong).SoSerialDoiChieu != devices.Single(t => t.MaThietBi == d.MaThietBi).SoSerial))
            return Results.BadRequest(new { loi = "Serial thực tế không khớp thiết bị đã bàn giao." });
        if(request.LyDoGhiNhanMuon?.Length>500)return Results.BadRequest();
        var actual = request.ThoiDiemThucNhan ?? RentalPolicy.LocalNow;
        if (actual.Kind != DateTimeKind.Unspecified || actual > RentalPolicy.LocalNow || details.Any(d => actual < d.NgayGiaoThucTe) ||
            request.ThietBi.Any(i => i.NgayNhanThucTe != null && i.NgayNhanThucTe != actual) ||
            request.ThoiDiemThucNhan.HasValue && string.IsNullOrWhiteSpace(request.LyDoGhiNhanMuon))
            return Results.BadRequest(new { loi = "Cần cùng thời điểm thực nhận hợp lệ và lý do nếu ghi nhận muộn." });
        if (await db.BienBanNhanTra.AnyAsync(b => b.MaHopDong == id, ct)) return Results.Conflict(new { loi = "Đã có biên bản nhận trả/ngoại lệ; cần đối soát, không lập lại." });
        var receipt = new BienBanNhanTra { Id = ApiAccess.NewId("NT"), MaHopDong = id, ThucNhanLuc = actual,
            NguoiGhiNhan = actor, GhiNhanLucUtc = DateTime.UtcNow, LyDoGhiNhanMuon = request.LyDoGhiNhanMuon?.Trim() };
        db.BienBanNhanTra.Add(receipt);
        foreach (var d in details) {
            var item = request.ThietBi.Single(i => i.MaChiTietHopDong == d.MaChiTietHopDong);
            d.MaBienBanNhanTra = receipt.Id; d.NgayNhanThucTe = actual; d.TinhTrangLucNhan = item.TinhTrang.Trim();
            d.CoHuHong = item.CoHuHong; d.KetQuaKiemTra = "CHUA_KIEM_TRA";
            devices.Single(t => t.MaThietBi == d.MaThietBi).TrangThai = "BAO_TRI";
        }
        h.TrangThai = "CHO_HOAN_TRA"; h.TrangThaiNhanTra = "DANG_KIEM_TRA";
        db.IdempotencyKey.Add(new() { IdempotencyKey = request.OperationId, MaKhachThue = h.MaKhachThue, LoaiThaoTac = "RETURN_ALL", PayloadHash = hash, MaThucThe = receipt.Id, NgayTao = RentalPolicy.LocalNow });

        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return Results.Ok(new { h.MaHopDong, h.TrangThai, maBienBan = receipt.Id, thoiGianNhanLai = actual, receipt.GhiNhanLucUtc });
    }

    public static void MapReturnWorkflowEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPut("/api/hop-dong/{id}/nhan-lai/thoi-gian",async(string id,FullReturnTimeCorrection r,ClaimsPrincipal p,RentalCameraContext db,CancellationToken ct)=>{
            var scope=await ApiAccess.StaffScopeAsync(p,db,ct);if(scope is null)return Results.Forbid();
            if(RentalPolicy.ProtectedContracts.Contains(id)||string.IsNullOrWhiteSpace(r.OperationId)||r.OperationId.Length>100||
                string.IsNullOrWhiteSpace(r.LyDo)||r.LyDo.Length>500||r.ThucNhanLuc.Kind!=DateTimeKind.Unspecified||r.ThucNhanLuc>RentalPolicy.LocalNow)return Results.BadRequest();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var s=await SettlementWorkflow.LoadAsync(id,db,ct);if(s is null)return Results.NotFound();
            if(!scope.IsAdmin&&scope.StoreId!=s.Contract.MaCuaHang)return Results.Forbid();
            var actor=ApiAccess.AccountId(p)!;var hash=SettlementJson.Hash(SettlementJson.Write(new{id,actor,r}));
            var key=await db.IdempotencyKey.SingleOrDefaultAsync(k=>k.IdempotencyKey==r.OperationId&&k.MaKhachThue==s.Contract.MaKhachThue&&k.LoaiThaoTac=="RETURN_TIME_ALL",ct);
            if(key!=null)return key.PayloadHash==hash?Results.Ok(new{doiSoat=true}):Results.Conflict();
            if(s.Final!=null||s.Receipt is null||s.Contract.TrangThai!="CHO_HOAN_TRA"||s.Receipt.ThucNhanLuc!=r.ThucNhanLucDaXem||
                s.Details.Count==0||s.Details.Any(d=>d.MaBienBanNhanTra!=s.Receipt.Id||d.NgayNhanThucTe==null||d.NgayGiaoThucTe==null||r.ThucNhanLuc<d.NgayGiaoThucTe))return Results.Conflict(new{loi="Biên bản đã đổi, chưa nhận đủ hoặc đã chốt quyết toán; không sửa lịch sử."});
            var deviceIds=s.Details.Select(d=>d.MaThietBi).ToArray();
            if(r.ThucNhanLuc>s.Receipt.ThucNhanLuc&&await db.ChiTietHopDong.AnyAsync(d=>deviceIds.Contains(d.MaThietBi)&&d.MaHopDong!=id&&
                db.HopDong.Any(h=>h.MaHopDong==d.MaHopDong&&h.TrangThai!="DA_HUY"&&h.TrangThai!="HOAN_THANH"&&h.ThoiGianBanGiao<r.ThucNhanLuc&&h.ThoiGianTraDuKien>s.Receipt.ThucNhanLuc),ct))return Results.Conflict(new{loi="Thời điểm mới xung đột lịch phân serial khác; cần đối soát riêng."});
            s.Receipt.ThucNhanLucTruocSua=s.Receipt.ThucNhanLuc;
            s.Receipt.NguoiSuaThucNhan=actor; s.Receipt.SuaThucNhanLucUtc=DateTime.UtcNow;
            s.Receipt.LyDoSuaThucNhan=r.LyDo.Trim(); s.Receipt.ThucNhanLuc=r.ThucNhanLuc;
            foreach(var d in s.Details)d.NgayNhanThucTe=r.ThucNhanLuc;

            db.IdempotencyKey.Add(new(){IdempotencyKey=r.OperationId,MaKhachThue=s.Contract.MaKhachThue,LoaiThaoTac="RETURN_TIME_ALL",PayloadHash=hash,MaThucThe=s.Receipt.Id,NgayTao=RentalPolicy.LocalNow});
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(new{s.Receipt.Id,s.Receipt.ThucNhanLuc});
        }).RequireAuthorization("Staff");
        app.MapPut("/api/hop-dong/{id}/nhan-lai/kiem-tra", async (string id, InspectionRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope is null) return Results.Forbid();
            if (RentalPolicy.ProtectedContracts.Contains(id)) return Results.Conflict();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var s = await SettlementWorkflow.LoadAsync(id, db, ct); if (s is null) return Results.NotFound();
            if (!scope.IsAdmin && scope.StoreId != s.Contract.MaCuaHang) return Results.Forbid();
            if(string.IsNullOrWhiteSpace(r.OperationId)||r.OperationId.Length>100)return Results.BadRequest();
            var payload=SettlementJson.Hash(SettlementJson.Write(new{id,actor=ApiAccess.AccountId(p),r}));
            var replay=await db.IdempotencyKey.SingleOrDefaultAsync(k=>k.IdempotencyKey==r.OperationId&&k.MaKhachThue==s.Contract.MaKhachThue&&k.LoaiThaoTac=="RETURN_INSPECT",ct);
            if(replay!=null)return replay.PayloadHash==payload?Results.Ok(new{maBienBan=replay.MaThucThe,doiSoat=true}):Results.Conflict();
            if (s.Final != null || s.Receipt?.ThucNhanLuc is null || s.Contract.TrangThai != "CHO_HOAN_TRA") return Results.Conflict(new { loi = "Chưa nhận đủ hoặc đã chốt quyết toán; không sửa tiền/lịch sử." });
            if(s.Receipt.KiemTraLucUtc!=r.KiemTraLucUtcDaXem)return Results.Conflict(new{loi="Kết quả kiểm tra đã đổi; đọc lại biên bản trước khi cập nhật."});
            if (r.ThietBi is null || r.ThietBi.Any(i=>i is null)) return Results.BadRequest();
            try { SettlementLedger.ValidateFullReturn(s.Details.Select(d => d.MaChiTietHopDong), r.ThietBi.Select(i => i.MaChiTietHopDong)); }
            catch (InvalidOperationException ex) { return Results.BadRequest(new { loi = ex.Message }); }
            if (r.ThietBi.Any(i => i.KetQua is not ("DAT" or "CO_VAN_DE") || string.IsNullOrWhiteSpace(i.TinhTrang) || i.TinhTrang.Length > 500 ||
                i.TinhTrangPhuKien?.Length > 1000 || i.ThieuPhuKien&&string.IsNullOrWhiteSpace(i.TinhTrangPhuKien) || i.KetQua == "DAT" && (i.CoHuHong || i.ThieuPhuKien))) return Results.BadRequest();
            var devices = await db.ThietBi.Where(t => s.Details.Select(d => d.MaThietBi).Contains(t.MaThietBi)).ToListAsync(ct);
            if(devices.Any(t=>t.TrangThai is not ("BAO_TRI" or "SAN_SANG")))return Results.Conflict(new{loi="Có thiết bị đã được phân cho lượt thuê khác; không ghi đè trạng thái kiểm tra."});
            foreach (var d in s.Details) {
                var item = r.ThietBi.Single(i => i.MaChiTietHopDong == d.MaChiTietHopDong);
                d.TinhTrangLucNhan = item.TinhTrang.Trim(); d.CoHuHong = item.CoHuHong; d.ThieuPhuKien = item.ThieuPhuKien;
                d.TinhTrangPhuKien = item.TinhTrangPhuKien?.Trim(); d.KetQuaKiemTra = item.KetQua;
                var t = devices.Single(t => t.MaThietBi == d.MaThietBi);
                t.TrangThai = item.KetQua == "DAT" ? "SAN_SANG" : "BAO_TRI"; t.TinhTrang = d.TinhTrangLucNhan;
            }
            s.Receipt.KiemTraLucUtc = DateTime.UtcNow; s.Receipt.NguoiKiemTra = ApiAccess.AccountId(p); s.Contract.TrangThaiNhanTra = "DA_KIEM_TRA";

            db.IdempotencyKey.Add(new(){IdempotencyKey=r.OperationId,MaKhachThue=s.Contract.MaKhachThue,LoaiThaoTac="RETURN_INSPECT",PayloadHash=payload,MaThucThe=s.Receipt.Id,NgayTao=RentalPolicy.LocalNow});
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Ok(new { s.Receipt.Id, s.Receipt.KiemTraLucUtc });
        }).RequireAuthorization("Staff");

        app.MapPost("/api/hop-dong/{id}/nhan-lai/ngoai-le", async (string id, ReturnExceptionRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope is null) return Results.Forbid();
            if (RentalPolicy.ProtectedContracts.Contains(id)) return Results.Conflict();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var s = await SettlementWorkflow.LoadAsync(id, db, ct); if (s is null) return Results.NotFound();
            if (!scope.IsAdmin && scope.StoreId != s.Contract.MaCuaHang) return Results.Forbid();
            if(string.IsNullOrWhiteSpace(r.OperationId)||r.OperationId.Length>100)return Results.BadRequest();
            var payload=SettlementJson.Hash(SettlementJson.Write(new{id,actor=ApiAccess.AccountId(p),r}));
            var replay=await db.IdempotencyKey.SingleOrDefaultAsync(k=>k.IdempotencyKey==r.OperationId&&k.MaKhachThue==s.Contract.MaKhachThue&&k.LoaiThaoTac=="RETURN_EXCEPTION",ct);
            if(replay!=null)return replay.PayloadHash==payload?Results.Ok(new{maBienBan=replay.MaThucThe,doiSoat=true}):Results.Conflict();
            if (s.Contract.TrangThai != "DANG_THUE" || s.Receipt != null || r.ThietBi is not { Count: > 0 } ||
                r.ThietBi.Any(x=>x is null) || r.ThietBi.Select(x => x.MaChiTietHopDong).Distinct().Count() != r.ThietBi.Count ||
                r.ThietBi.Any(x => !s.Details.Any(d => d.MaChiTietHopDong == x.MaChiTietHopDong) || x.Loai is not ("THIEU_THIET_BI" or "BAO_MAT") || string.IsNullOrWhiteSpace(x.LyDo) || x.LyDo.Length > 500)) return Results.Conflict();
            var receipt = new BienBanNhanTra { Id = ApiAccess.NewId("NT"), MaHopDong = id,
                NguoiGhiNhan = ApiAccess.AccountId(p)!, GhiNhanLucUtc = DateTime.UtcNow };
            db.BienBanNhanTra.Add(receipt); s.Contract.TrangThaiNhanTra = "NGOAI_LE";
            foreach (var item in r.ThietBi) {
                var d = s.Details.Single(d => d.MaChiTietHopDong == item.MaChiTietHopDong);
                var serial = await db.ThietBi.Where(t => t.MaThietBi == d.MaThietBi).Select(t => t.SoSerial).SingleAsync(ct);
                if (serial != item.SoSerial) return Results.BadRequest(new { loi = "Serial ngoại lệ không khớp." });
                d.MaBienBanNhanTra = receipt.Id; d.LoaiNgoaiLeNhanTra = item.Loai; d.LyDoNgoaiLeNhanTra = item.LyDo.Trim();
            }

            db.IdempotencyKey.Add(new(){IdempotencyKey=r.OperationId,MaKhachThue=s.Contract.MaKhachThue,LoaiThaoTac="RETURN_EXCEPTION",PayloadHash=payload,MaThucThe=receipt.Id,NgayTao=RentalPolicy.LocalNow});
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Ok(receipt);
        }).RequireAuthorization("Staff");
    }
}

public sealed record InspectionRequest(List<InspectionItem> ThietBi, string OperationId, DateTime? KiemTraLucUtcDaXem=null);
public sealed record InspectionItem(string MaChiTietHopDong, string TinhTrang, bool CoHuHong, bool ThieuPhuKien, string KetQua, string? TinhTrangPhuKien = null);
public sealed record ReturnExceptionRequest(List<ReturnExceptionItem> ThietBi, string OperationId);
public sealed record ReturnExceptionItem(string MaChiTietHopDong, string SoSerial, string Loai, string LyDo);
public sealed record FullReturnTimeCorrection(string OperationId,DateTime ThucNhanLucDaXem,DateTime ThucNhanLuc,string LyDo);
