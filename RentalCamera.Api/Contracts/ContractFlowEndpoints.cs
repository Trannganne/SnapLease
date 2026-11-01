using RentalCamera.Api.Contracts;
using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.Data.SqlClient;
using RentalCamera.Api.Data;
using RentalCamera.Api.Email;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Notifications;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Contracts;

public static class ContractEndpoints
{
    public static void MapContractEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/giu-cho/{id}/xac-nhan-thue", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db,
            AvailabilityService availability,
            IConfiguration configuration,
            FirebaseNotificationSender notificationSender, ILoggerFactory loggerFactory,
            HttpContext httpContext, CancellationToken ct) =>
        {
            var logger = loggerFactory.CreateLogger("ContractFlow");
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            var existingContract = await db.HopDong.FirstOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (existingContract != null)
            {
                return Results.Ok(new
                {
                    existingContract.MaHopDong, existingContract.MaGioHang, existingContract.MaGiuCho,
                    existingContract.MaKhachThue, existingContract.MaNhanVien, existingContract.MaCuaHang,
                    existingContract.NgayTaoHopDong, existingContract.NgayKy,
                    existingContract.ThoiGianBanGiao, existingContract.ThoiGianTraDuKien,
                    existingContract.TongTien, existingContract.TongTienCoc, existingContract.TrangThai
                });
            }

            try
            {
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "cart:" + customerId, ct);
            var completedRetry = await db.HopDong.SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (completedRetry is not null) return Results.Ok(new { completedRetry.MaHopDong, completedRetry.TrangThai });
            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            if (hold is null) return Results.NotFound();
            if (hold.TrangThai != "DANG_GIU" || hold.HetHanLuc <= DateTime.UtcNow || hold.ChiTiet.Count == 0)
            {
                if (hold.TrangThai == "DANG_GIU" && hold.HetHanLuc <= DateTime.UtcNow)
                {
                    hold.TrangThai = "HET_HAN";
                    await db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);
                }
                return Results.Conflict(new { loi = "Giữ chỗ không còn hiệu lực." });
            }
            var khachThue = await db.KhachThue.SingleOrDefaultAsync(x => x.MaKhachThue == customerId, ct);
            if (khachThue is null) return Results.NotFound();

            if (!khachThue.DaXacNhanThongTin)
                return Results.Conflict(new { loi = "Khách hàng chưa xác nhận thông tin cá nhân." });

            if (string.IsNullOrWhiteSpace(khachThue.CCCD) || string.IsNullOrWhiteSpace(khachThue.HoTen) ||
                !khachThue.NgaySinh.HasValue || string.IsNullOrWhiteSpace(khachThue.GioiTinh) ||
                string.IsNullOrWhiteSpace(khachThue.QuocTich) || string.IsNullOrWhiteSpace(khachThue.DiaChi) ||
                !khachThue.NgayCap.HasValue || string.IsNullOrWhiteSpace(khachThue.NoiCap))
            {
                return Results.Conflict(new { loi = "Hồ sơ khách hàng thiếu thông tin bắt buộc." });
            }

            var giayTo = await db.GiayToTuyThan
                .Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTaiLen)
                .FirstOrDefaultAsync(ct);

            if (giayTo is null)
                return Results.Conflict(new { loi = "Khách hàng chưa có giấy tờ tùy thân." });

            if (string.IsNullOrWhiteSpace(giayTo.MatTruocUrl) || string.IsNullOrWhiteSpace(giayTo.MatSauUrl))
                return Results.Conflict(new { loi = "Giấy tờ tùy thân chưa đủ hai mặt ảnh." });

            if (!IsIdentityVerifiedForRental(giayTo))
                return Results.Conflict(new { loi = "Giấy tờ tùy thân chưa được xác minh hợp lệ." });

            var selections=await db.ChiTietGiuCho.AsNoTracking().Where(x=>x.MaGiuCho==id).ToListAsync(ct);
            var originalIds=selections.Count>0?selections.Select(x=>x.MaChiTietGioHang).ToArray():
                hold.ChiTiet.Where(x=>x.MaChiTietGioHang!=null).Select(x=>x.MaChiTietGioHang!).ToArray();
            var originalLines=await db.ChiTietGioHang.Where(x=>originalIds.Contains(x.MaChiTietGioHang)&&x.GioHang.MaKhachThue==customerId)
                .ToDictionaryAsync(x=>x.MaChiTietGioHang,ct);
            if (selections.Any(s => !originalLines.TryGetValue(s.MaChiTietGioHang, out var original) ||
                original.PhienBan != s.PhienBanGioHang || original.DaChuyenHopDong || original.MaDongMay != s.MaDongMay || original.SoLuong != s.SoLuong))
                return Results.Conflict(new { code = "CART_VERSION_CONFLICT" });
            var modelIds = hold.ChiTiet.Select(x => x.MaDongMay).Distinct().ToList();
            var models = await db.DongMay.Where(x => modelIds.Contains(x.MaDongMay))
                .ToDictionaryAsync(x => x.MaDongMay, ct);
            if (models.Count != modelIds.Count)
                return Results.Conflict(new { loi = "Dữ liệu dòng máy trong giữ chỗ không còn hợp lệ." });

            var limit = RentalRiskPolicy.Evaluate(
                hold.ChiTiet.Select(x => (models[x.MaDongMay].TienCoc, x.SoLuong)), configuration);
            if (!limit.Allowed) return Results.Conflict(RentalRiskPolicy.LimitError(limit));

            foreach (var selected in hold.ChiTiet.GroupBy(x => x.MaDongMay).OrderBy(x => x.Key))
            {
                var available = await availability.GetAvailableAsync(hold.MaCuaHang, selected.Key,
                    selected.Min(x => x.NgayBatDau), selected.Max(x => x.NgayKetThuc), hold.MaGiuCho, null, ct);
                if (available < selected.Sum(x => x.SoLuong))
                    return Results.Conflict(new { loi = "Không đủ thiết bị khi xác nhận thuê." });
            }
            // A contract owns an immutable, selected-only price snapshot. The active cart remains independent.
            var contractCart = new GioHang { MaGioHang = ApiAccess.NewId("GH"), MaKhachThue = customerId,
                TrangThai = "DA_CHUYEN_HOP_DONG", NgayTao = DateTime.UtcNow, NgayCapNhat = DateTime.UtcNow };
            db.GioHang.Add(contractCart);
            foreach(var selected in selections)
                if(originalLines.TryGetValue(selected.MaChiTietGioHang,out var original)&&!original.DaChuyenHopDong&&CartEndpoints.SameSelectedVersion(selected,original))
                    original.DaChuyenHopDong=true;

            decimal total = 0;
            decimal deposit = 0;
            foreach (var line in hold.ChiTiet)
            {
                var model = models[line.MaDongMay];
                var days = (decimal)Math.Ceiling((line.NgayKetThuc - line.NgayBatDau).TotalDays);
                var unitPrice = Math.Round(model.GiaThueNgay * (100 - model.PhanTramGiamGia) / 100, 2);
                total += unitPrice * days * line.SoLuong;
                deposit += model.TienCoc * line.SoLuong;

                var cartLine = line.MaChiTietGioHang != null 
                    ? originalLines.GetValueOrDefault(line.MaChiTietGioHang)
                    : null;
                if (cartLine is not null && !cartLine.DaChuyenHopDong &&
                    (line.PhienBanGioHang == cartLine.PhienBan || cartLine.NguonTao == "THUE_NGAY"))
                {
                    cartLine.DaChuyenHopDong = true;
                }
                var snapshotLine = new ChiTietGioHang { MaChiTietGioHang = ApiAccess.NewId("CG"),
                    MaGioHang = contractCart.MaGioHang, MaCuaHang = hold.MaCuaHang, NguonTao = "GIO_HANG",
                    MaDongMay = line.MaDongMay, SoLuong = line.SoLuong, NgayBatDau = line.NgayBatDau,
                    NgayKetThuc = line.NgayKetThuc, DonGia = unitPrice, TienCoc = model.TienCoc,
                    ThanhTien = unitPrice * days * line.SoLuong, DaChuyenHopDong = true };
                db.ChiTietGioHang.Add(snapshotLine);
                line.MaChiTietGioHangHopDong = snapshotLine.MaChiTietGioHang;
            }
            hold.MaGioHang = contractCart.MaGioHang;

            var contract = new HopDong
            {
                MaHopDong = ApiAccess.NewId("HD"), MaGioHang = contractCart.MaGioHang,
                MaGiuCho = hold.MaGiuCho, MaKhachThue = customerId,
                MaNhanVien = null, MaCuaHang = hold.MaCuaHang,
                NgayTaoHopDong = RentalPolicy.LocalNow, NgayKy = null,
                ThoiGianBanGiao = hold.ChiTiet.Min(x => x.NgayBatDau),
                ThoiGianTraDuKien = hold.ChiTiet.Max(x => x.NgayKetThuc),
                TongTien = total, TongTienCoc = deposit,
                HinhThucKy = null, TrangThai = "CHO_KY", TepHopDongUrl = null,
                DaDongYDieuKhoan = false, PhienBanDieuKhoan = RentalPolicy.TermsVersion,
                MaBamNoiDung = null, MaBamTepPdf = null, NoiDungHopDongJson = null
            };
            db.HopDong.Add(contract);
            hold.TrangThai = "DA_CHUYEN_HOP_DONG";

            var accountId = await db.KhachThue.AsNoTracking()
                .Where(x => x.MaKhachThue == customerId)
                .Select(x => x.MaTaiKhoan).SingleAsync(ct);
            const string notificationTitle = "Hợp đồng chờ ký";
            var notificationBody = $"Hợp đồng {contract.MaHopDong} đã được tạo và đang chờ ký.";
            ApiAccess.AddNotification(db, accountId, "HOP_DONG", notificationTitle, notificationBody,
                eventCode: "CONTRACT_CREATED", targetType: "HOP_DONG", targetId: contract.MaHopDong);

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created($"/api/hop-dong/{contract.MaHopDong}", new
            {
                contract.MaHopDong, contract.MaGiuCho, contract.TongTien,
                contract.TongTienCoc, contract.TrangThai, contract.NgayTaoHopDong
            });
            }
            catch (DbUpdateException dbEx) when (dbEx.InnerException is SqlException sqlEx && (sqlEx.Number == 2601 || sqlEx.Number == 2627))
            {
                logger.LogWarning("Xung đột tạo hợp đồng (MaGiuCho unique): {Id}", id);
                var recoveredContract = await db.HopDong.FirstOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
                if (recoveredContract != null)
                {
                    return Results.Ok(new
                    {
                        recoveredContract.MaHopDong, recoveredContract.MaGioHang, recoveredContract.MaGiuCho,
                        recoveredContract.MaKhachThue, recoveredContract.MaNhanVien, recoveredContract.MaCuaHang,
                        recoveredContract.NgayTaoHopDong, recoveredContract.NgayKy,
                        recoveredContract.ThoiGianBanGiao, recoveredContract.ThoiGianTraDuKien,
                        recoveredContract.TongTien, recoveredContract.TongTienCoc, recoveredContract.TrangThai
                    });
                }
                logger.LogError(dbEx, "Lỗi CSDL (Unique) khi tạo hợp đồng cho giữ chỗ {MaGiuCho}. TraceId: {TraceId}", id, httpContext.TraceIdentifier);
                return Results.Json(new { loi = "Lỗi hệ thống khi tạo hợp đồng.", traceId = httpContext.TraceIdentifier }, statusCode: 500);
            }
            catch (DbUpdateException dbEx)
            {
                logger.LogError(dbEx, "Lỗi CSDL khi tạo hợp đồng cho giữ chỗ {MaGiuCho}. TraceId: {TraceId}", id, httpContext.TraceIdentifier);
                return Results.Json(new { loi = "Lỗi hệ thống khi tạo hợp đồng.", traceId = httpContext.TraceIdentifier }, statusCode: 500);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Lỗi hệ thống khi tạo hợp đồng cho giữ chỗ {MaGiuCho}. TraceId: {TraceId}", id, httpContext.TraceIdentifier);
                return Results.Json(new { loi = "Lỗi hệ thống khi tạo hợp đồng.", traceId = httpContext.TraceIdentifier }, statusCode: 500);
            }
        }).RequireAuthorization("Customer");

        var contracts = app.MapGroup("/api/hop-dong").RequireAuthorization();

        contracts.MapGet("/cua-toi", async (
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.HopDong.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTaoHopDong)
                .Select(x => new
                {
                    x.MaHopDong, x.MaGiuCho, x.MaCuaHang, x.NgayTaoHopDong, x.NgayKy,
                    x.ThoiGianBanGiao, x.ThoiGianTraDuKien,
                    x.TongTien, x.TongTienCoc, x.TrangThai,
                    TenCuaHang = db.CuaHang.Where(c => c.MaCuaHang == x.MaCuaHang).Select(c => c.TenCuaHang).FirstOrDefault() ?? "",
                    ThietBi = db.ChiTietGiuCho.Where(ct => ct.MaGiuCho == x.MaGiuCho)
                        .Join(db.DongMay, ct => ct.MaDongMay, dm => dm.MaDongMay, (ct, dm) => dm)
                        .Select(dm => new
                        {
                            TenDongMay = dm.TenDongMay,
                            HinhAnh = dm.AnhThietBi.Where(a => a.LaAnhDaiDien).Select(a => a.DuongDanAnh).FirstOrDefault()
                                      ?? dm.AnhThietBi.Select(a => a.DuongDanAnh).FirstOrDefault() ?? ""
                        }).FirstOrDefault(),
                    SoLuongThietBi = db.ChiTietGiuCho.Count(ct => ct.MaGiuCho == x.MaGiuCho)
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");

        contracts.MapGet("/theo-giu-cho/{maGiuCho}", async (
            string maGiuCho, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().FirstOrDefaultAsync(x => x.MaGiuCho == maGiuCho && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            return Results.Ok(new { contract.MaHopDong });
        }).RequireAuthorization("Customer");

        contracts.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, RentalCamera.Api.Payments.VnpayService gateway,
            Microsoft.Extensions.Options.IOptions<RentalCamera.Api.Payments.VnpayOptions> gatewayOptions, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();

            var khachThue = await db.KhachThue.AsNoTracking().SingleOrDefaultAsync(x => x.MaKhachThue == contract.MaKhachThue, ct);
            var cuaHang = await db.CuaHang.AsNoTracking().SingleOrDefaultAsync(x => x.MaCuaHang == contract.MaCuaHang, ct);

            var bookedList = await db.ChiTietGiuCho.AsNoTracking().Where(x => x.MaGiuCho == contract.MaGiuCho).ToListAsync(ct);
            var modelIds = bookedList.Select(x => x.MaDongMay).Distinct().ToList();
            var models = await db.DongMay.AsNoTracking().Where(x => modelIds.Contains(x.MaDongMay)).ToDictionaryAsync(x => x.MaDongMay, ct);
            var snapshotIds=bookedList.Where(x=>x.MaChiTietGioHangHopDong!=null).Select(x=>x.MaChiTietGioHangHopDong!).ToArray();
            var priceSnapshots=await db.ChiTietGioHang.AsNoTracking()
                .Where(snapshotLine=>snapshotIds.Contains(snapshotLine.MaChiTietGioHang) &&
                    snapshotLine.MaGioHang==contract.MaGioHang && snapshotLine.GioHang.TrangThai=="DA_CHUYEN_HOP_DONG")
                .ToDictionaryAsync(snapshotLine=>snapshotLine.MaChiTietGioHang,ct);

            var booked = bookedList.Select(x => new {
                x.MaDongMay,
                TenDongMay = models.ContainsKey(x.MaDongMay) ? models[x.MaDongMay].TenDongMay : null,
                DonGiaTieuChuan = x.MaChiTietGioHangHopDong!=null&&priceSnapshots.ContainsKey(x.MaChiTietGioHangHopDong)?(decimal?)priceSnapshots[x.MaChiTietGioHangHopDong].DonGia:null,
                ThanhTien = x.MaChiTietGioHangHopDong!=null&&priceSnapshots.ContainsKey(x.MaChiTietGioHangHopDong)?(decimal?)priceSnapshots[x.MaChiTietGioHangHopDong].ThanhTien:null,
                NguonGia = x.MaChiTietGioHangHopDong!=null&&priceSnapshots.ContainsKey(x.MaChiTietGioHangHopDong)?"ANH_CHUP_HOP_DONG":"CHUA_XAC_DINH",
                x.SoLuong, x.NgayBatDau, x.NgayKetThuc,
                SoNgayThue = (decimal)Math.Ceiling((x.NgayKetThuc - x.NgayBatDau).TotalDays)
            }).ToList();

            var detailRows = await db.ChiTietHopDong.AsNoTracking().Where(x => x.MaHopDong == id)
                .Join(db.ThietBi.AsNoTracking(), c => c.MaThietBi, t => t.MaThietBi, (c, t) => new
                {
                    c.MaChiTietHopDong, c.MaThietBi, t.MaDongMay, t.SoSerial,
                    c.DonGia, c.TinhTrangLucGiao, c.NgayGiaoThucTe,
                    c.TinhTrangLucNhan, c.NgayNhanThucTe, c.CoHuHong
                }).ToListAsync(ct);
            var detailIds = detailRows.Select(x => x.MaChiTietHopDong).ToList();
            var images = await db.AnhBienBan.AsNoTracking()
                .Where(x => detailIds.Contains(x.MaChiTietHopDong)).ToListAsync(ct);
            var details = detailRows.Select(x => new
            {
                x.MaChiTietHopDong, x.MaThietBi, x.MaDongMay, x.SoSerial, x.DonGia,
                x.TinhTrangLucGiao, x.NgayGiaoThucTe, x.TinhTrangLucNhan,
                x.NgayNhanThucTe, x.CoHuHong,
                AnhBienBan = images.Where(a => a.MaChiTietHopDong == x.MaChiTietHopDong).ToList()
            }).ToList();
            var payments = await db.ThanhToan.AsNoTracking().Where(x => x.MaHopDong == id)
                .OrderBy(x => x.ThoiGian).ToListAsync(ct);
            await using(var expirationTx=await db.Database.BeginTransactionAsync(ct)) {
                await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
                await RenewalEndpoints.ExpireAsync(id,db,ct);await expirationTx.CommitAsync(ct);
            }
            var supplements = await db.PhuLuc.AsNoTracking().Where(x => x.MaHopDong == id)
                .OrderBy(x => x.NgayLap).ToListAsync(ct);
            object? settlementView=null;
            if(contract.TrangThai is "DANG_THUE" or "CHO_HOAN_TRA" or "HOAN_THANH") {
                var s=await RentalCamera.Api.Settlement.SettlementWorkflow.LoadAsync(id,db,ct);
                if(s!=null)settlementView=await RentalCamera.Api.Settlement.SettlementViewService.ViewAsync(s,principal,
                    RentalCamera.Api.Settlement.SettlementViewService.SandboxReady(gateway,gatewayOptions.Value),db,ct);
            }

            return Results.Ok(new
            {
                contract.MaHopDong, contract.MaGioHang, contract.MaGiuCho,
                contract.MaKhachThue, contract.MaNhanVien, contract.MaCuaHang,
                contract.NgayTaoHopDong, contract.NgayKy,
                contract.ThoiGianBanGiao, contract.ThoiGianTraDuKien,
                contract.TongTien, contract.TongTienCoc, contract.HinhThucKy,
                contract.TrangThai, contract.TepHopDongUrl,
                KhachThue = khachThue,
                ChiNhanh = cuaHang,
                contract.DaDongYDieuKhoan, contract.PhienBanDieuKhoan,
                contract.MaBamNoiDung, contract.MaBamTepPdf,
                DatTheoDongMay = booked, ChiTiet = details,
                QuyetToan = settlementView,
                ThanhToan = payments, PhuLuc = supplements.Select(RenewalEndpoints.Dto),
                ThoiHanTraHieuLuc = await RenewalEndpoints.EffectiveReturnAsync(contract, db, ct),
                ThoiGianServer = DateTime.UtcNow,
                LyDoKhongTheGiaHan = !RentalPolicy.CanUseExtensionTerms(contract.PhienBanDieuKhoan,contract.DaDongYDieuKhoan)?"Cần cửa hàng kiểm tra điều khoản/bằng chứng đã ký trước khi báo giá gia hạn.":null,
                CoTheYeuCauGiaHan = RentalPolicy.CanUseExtensionTerms(contract.PhienBanDieuKhoan,contract.DaDongYDieuKhoan)&&RentalPolicy.CanRequestExtension(new(contract.TrangThai,
                    await RenewalEndpoints.EffectiveReturnAsync(contract, db, ct), detailRows.Any(d=>d.NgayNhanThucTe!=null)), DateTime.UtcNow),
                TienTraTre = await LateReturnService.QuoteAsync(id, db, ct),
                DoiSoatHuy = await db.DoiSoatHuyHopDong.AsNoTracking().SingleOrDefaultAsync(x=>x.MaHopDong==id,ct),
                HoanTienHuy = payments.Where(p=>p.MaDoiSoatHuyHopDong!=null).Select(p=>new{p.MaThanhToan,p.LoaiThanhToan,p.SoTien,p.TrangThai})
            });
        });

        contracts.MapPut("/{id}/tep-pdf", async (
            string id, HttpRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, ContractPdfService pdfService, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (!string.Equals(request.ContentType?.Split(';')[0].Trim(), "application/pdf",
                    StringComparison.OrdinalIgnoreCase))
                return Results.BadRequest(new { loi = "Content-Type phải là application/pdf." });
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            await using var tx=await db.Database.BeginTransactionAsync(ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Chỉ được cập nhật PDF khi hợp đồng đang chờ ký." });

            try
            {
                var saved = await pdfService.SaveAsync(id, request.Body, ct);
                contract.TepHopDongUrl = $"/api/hop-dong/{id}/tep-pdf";
                contract.MaBamTepPdf = saved.Sha256;
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                return Results.Ok(new
                {
                    contract.MaHopDong, contract.TepHopDongUrl,
                    maBamTepPdf = saved.Sha256,
                    kichThuocByte = saved.SizeBytes,
                    thuatToan = "SHA-256"
                });
            }
            catch (InvalidDataException ex)
            {
                return Results.BadRequest(new { loi = ex.Message });
            }
        }).RequireAuthorization("Customer");

        contracts.MapGet("/{id}/tep-pdf", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db,
            ContractPdfService pdfService, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (string.IsNullOrWhiteSpace(contract.MaBamTepPdf) ||
                !await pdfService.VerifyAsync(id, contract.MaBamTepPdf, ct))
                return Results.Conflict(new { loi = "Tệp PDF không tồn tại hoặc không còn khớp mã băm đã lưu." });
            return Results.File(pdfService.OpenRead(id), "application/pdf", $"{id}.pdf",
                enableRangeProcessing: true);
        });

        contracts.MapPost("/{id}/yeu-cau-ky", async (
            string id, RequestContractSignatureRequest request, HttpContext httpContext,
            ClaimsPrincipal principal, RentalCameraContext db,
            ContractSignatureService signatureService, ContractPdfService pdfService,
            [FromKeyedServices(ContractSigningOtpRegistration.ServiceKey)] IContractOtpEmailSender emailSender, IConfiguration configuration,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (!request.DaDongYDieuKhoan)
                return Results.BadRequest(new { loi = "Bạn phải đọc và đồng ý điều khoản hợp đồng trước khi ký." });

            var allowTestResponse = configuration.GetValue(
                "ElectronicSignature:ReturnOtpInResponse", false);
            if (!emailSender.IsConfigured && !allowTestResponse)
                return Results.Problem(
                    title: "Dịch vụ gửi OTP qua email chưa được cấu hình.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var recipient = await db.KhachThue.AsNoTracking()
                .Where(x => x.MaKhachThue == customerId)
                .Select(x => new { x.HoTen, x.Email })
                .SingleOrDefaultAsync(ct);
            if (recipient is null) return Results.Forbid();
            if (emailSender.IsConfigured && string.IsNullOrWhiteSpace(recipient.Email))
                return Results.BadRequest(new
                {
                    loi = "Tài khoản khách hàng chưa có email để nhận OTP ký hợp đồng."
                });

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Hợp đồng không ở trạng thái chờ ký." });
            if (string.IsNullOrWhiteSpace(contract.MaBamTepPdf) ||
                !await pdfService.VerifyAsync(id, contract.MaBamTepPdf, ct))
                return Results.Conflict(new { loi = "Hợp đồng chưa có PDF hợp lệ để ký." });
            var timeout = Math.Clamp(configuration.GetValue("Rental:ContractSignMinutes", 30), 1, 1440);
            var now = RentalPolicy.LocalNow;
            if (contract.NgayTaoHopDong.AddMinutes(timeout) <= now)
            {
                contract.TrangThai = "DA_HUY";
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                return Results.Conflict(new { loi = "Hợp đồng đã quá thời hạn ký và đã bị hủy." });
            }

            var recentRequests = await db.XacNhanKyHopDong.AsNoTracking()
                .Where(x => x.MaHopDong == id && x.TrangThai == "CHO_XAC_NHAN")
                .OrderByDescending(x => x.TaoLuc)
                .ToListAsync(ct);

            if (recentRequests.Count > 0 && (now - recentRequests[0].TaoLuc).TotalSeconds < 60)
                return Results.Conflict(new { loi = "Vui lòng đợi 60 giây trước khi yêu cầu gửi lại OTP." });

            if (recentRequests.Count >= 5)
                return Results.Conflict(new { loi = "Bạn đã yêu cầu gửi mã quá 5 lần cho hợp đồng này. Vui lòng liên hệ hỗ trợ." });

            if (string.IsNullOrWhiteSpace(contract.PhienBanDieuKhoan))
                return Results.Conflict(new { loi = "Hợp đồng cũ chưa xác định phiên bản điều khoản; cần cửa hàng đối chiếu trước khi ký." });
            var termsVersion = contract.PhienBanDieuKhoan;
            var snapshotJson = await BuildContractSnapshotAsync(contract, db, termsVersion, ct);
            var contentHash = signatureService.HashContent(snapshotJson);
            var otp = signatureService.GenerateOtp();
            var (otpHash, salt) = signatureService.HashOtp(otp);
            var lifetimeMinutes = Math.Clamp(
                configuration.GetValue("ElectronicSignature:OtpLifetimeMinutes", 5), 1, 15);

            foreach (var pending in recentRequests)
            {
                // We need to fetch tracking entity since recentRequests is AsNoTracking
                var entityToCancel = await db.XacNhanKyHopDong.FindAsync(new object[] { pending.MaXacNhan }, ct);
                if (entityToCancel != null) entityToCancel.TrangThai = "DA_HUY";
            }

            var confirmation = new XacNhanKyHopDong
            {
                MaXacNhan = ApiAccess.NewId("XK"),
                MaHopDong = id,
                MaOtpHash = otpHash,
                MuoiOtp = salt,
                TaoLuc = now,
                HetHanLuc = now.AddMinutes(lifetimeMinutes),
                SoLanThu = 0,
                TrangThai = "CHO_XAC_NHAN",
                DiaChiIp = GetClientIp(httpContext),
                ThietBiKy = GetUserAgent(httpContext),
                PhienBanDieuKhoan = termsVersion,
                MaBamNoiDung = contentHash,
                MaBamTepPdf = contract.MaBamTepPdf,
                NoiDungHopDongJson = snapshotJson
            };
            db.XacNhanKyHopDong.Add(confirmation);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            var emailSent = false;
            if (emailSender.IsConfigured)
            {
                try
                {
                    await emailSender.SendAsync(
                        recipient.Email!, recipient.HoTen ?? "khách hàng",
                        id, otp, confirmation.HetHanLuc, ct);
                    emailSent = true;
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    throw;
                }
                catch
                {
                    confirmation.TrangThai = "DA_HUY";
                    await db.SaveChangesAsync(ct);
                    return Results.Problem(
                        title: "Không thể gửi OTP qua email. Yêu cầu ký đã được hủy; vui lòng thử lại.",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
            }

            var exposeOtp = allowTestResponse && !emailSent;

            return Results.Accepted(value: new
            {
                confirmation.MaXacNhan,
                confirmation.MaHopDong,
                confirmation.HetHanLuc,
                confirmation.PhienBanDieuKhoan,
                confirmation.MaBamNoiDung,
                confirmation.MaBamTepPdf,
                maOtp = exposeOtp ? otp : null,
                kenhGui = emailSent ? "EMAIL" : "RESPONSE_KIEM_THU",
                emailNhan = emailSent ? MaskEmail(recipient.Email) : null,
                thongBao = emailSent
                    ? "Đã gửi OTP ký hợp đồng tới email của khách hàng."
                    : "Đã tạo OTP ký hợp đồng để kiểm thử."
            });
        }).RequireAuthorization("Customer").RequireRateLimiting("auth");

        contracts.MapPut("/{id}/ky", async (
            string id, SignContractRequest request, HttpContext httpContext,
            ClaimsPrincipal principal, RentalCameraContext db,
            ContractSignatureService signatureService, ContractPdfService pdfService,
            IConfiguration configuration,
            CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (!request.DaDongYDieuKhoan)
                return Results.BadRequest(new { loi = "Bạn phải đồng ý điều khoản tại thời điểm xác nhận OTP." });
            if (string.IsNullOrWhiteSpace(request.MaXacNhan) ||
                string.IsNullOrWhiteSpace(request.MaOtp) || request.MaOtp.Length != 6 ||
                request.MaOtp.Any(x => !char.IsDigit(x)))
                return Results.BadRequest(new { loi = "Mã xác nhận hoặc OTP không hợp lệ." });
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Hợp đồng không ở trạng thái chờ ký." });

            var confirmation = await db.XacNhanKyHopDong.SingleOrDefaultAsync(
                x => x.MaXacNhan == request.MaXacNhan.Trim() && x.MaHopDong == id, ct);
            if (confirmation is null) return Results.BadRequest(new { loi = "Không tìm thấy yêu cầu ký." });
            if (confirmation.TrangThai != "CHO_XAC_NHAN")
                return Results.Conflict(new { loi = "Yêu cầu ký đã được xử lý hoặc bị hủy." });
            if (string.IsNullOrWhiteSpace(contract.MaBamTepPdf) ||
                string.IsNullOrWhiteSpace(confirmation.MaBamTepPdf) ||
                !string.Equals(contract.MaBamTepPdf, confirmation.MaBamTepPdf,
                    StringComparison.OrdinalIgnoreCase) ||
                !await pdfService.VerifyAsync(id, confirmation.MaBamTepPdf, ct))
                return Results.Conflict(new { loi = "PDF đã thay đổi sau khi tạo OTP; hãy tạo yêu cầu ký mới." });

            var now = RentalPolicy.LocalNow;
            if (confirmation.HetHanLuc <= now)
            {
                confirmation.TrangThai = "HET_HAN";
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                return Results.BadRequest(new { loi = "OTP ký hợp đồng đã hết hạn." });
            }

            var maxAttempts = Math.Clamp(
                configuration.GetValue("ElectronicSignature:MaxAttempts", 5), 1, 10);
            if (!signatureService.VerifyOtp(request.MaOtp, confirmation.MaOtpHash, confirmation.MuoiOtp))
            {
                confirmation.SoLanThu++;
                if (confirmation.SoLanThu >= maxAttempts) confirmation.TrangThai = "KHOA";
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                return Results.BadRequest(new
                {
                    loi = confirmation.TrangThai == "KHOA"
                        ? "OTP sai quá số lần cho phép; hãy tạo yêu cầu ký mới."
                        : "OTP không đúng.",
                    soLanConLai = Math.Max(0, maxAttempts - confirmation.SoLanThu)
                });
            }

            confirmation.SoLanThu++;
            confirmation.TrangThai = "DA_XAC_NHAN";
            confirmation.XacNhanLuc = now;
            confirmation.DiaChiIp = GetClientIp(httpContext);
            confirmation.ThietBiKy = GetUserAgent(httpContext);

            contract.NgayKy = now;
            contract.HinhThucKy = "DIEN_TU";
            contract.DaDongYDieuKhoan = true;
            contract.PhienBanDieuKhoan = confirmation.PhienBanDieuKhoan;
            contract.MaBamNoiDung = confirmation.MaBamNoiDung;
            contract.NoiDungHopDongJson = confirmation.NoiDungHopDongJson;
            contract.TrangThai = "DA_KY";
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            return Results.Ok(new
            {
                contract.MaHopDong, contract.NgayKy, contract.HinhThucKy,
                contract.TrangThai, contract.TepHopDongUrl,
                contract.DaDongYDieuKhoan, contract.PhienBanDieuKhoan,
                contract.MaBamNoiDung, contract.MaBamTepPdf,
                loaiKy = "XAC_NHAN_DIEN_TU_MO_PHONG",
                thongBao = "Xác nhận hợp đồng bằng OTP thành công."
            });
        }).RequireAuthorization("Customer").RequireRateLimiting("auth");

        contracts.MapGet("/{id}/lich-su-ky", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var rows = await db.XacNhanKyHopDong.AsNoTracking()
                .Where(x => x.MaHopDong == id)
                .OrderByDescending(x => x.TaoLuc)
                .Select(x => new
                {
                    x.MaXacNhan, x.MaHopDong, x.TaoLuc, x.HetHanLuc,
                    x.SoLanThu, x.TrangThai, x.XacNhanLuc,
                    x.DiaChiIp, x.ThietBiKy, x.PhienBanDieuKhoan,
                    x.MaBamNoiDung, x.MaBamTepPdf
                }).ToListAsync(ct);
            return Results.Ok(rows);
        });

        contracts.MapGet("/{id}/noi-dung-da-ky", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db,
            ContractSignatureService signatureService, ContractPdfService pdfService,
            CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking()
                .SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai == "CHO_KY" || string.IsNullOrWhiteSpace(contract.NoiDungHopDongJson) ||
                string.IsNullOrWhiteSpace(contract.MaBamNoiDung))
                return Results.Conflict(new { loi = "Hợp đồng chưa có nội dung đã xác nhận." });

            var calculatedHash = signatureService.HashContent(contract.NoiDungHopDongJson);
            var pdfHashIsValid = !string.IsNullOrWhiteSpace(contract.MaBamTepPdf) &&
                                 await pdfService.VerifyAsync(id, contract.MaBamTepPdf, ct);
            return Results.Ok(new
            {
                contract.MaHopDong,
                contract.NgayKy,
                contract.PhienBanDieuKhoan,
                contract.MaBamNoiDung,
                maBamHopLe = string.Equals(calculatedHash, contract.MaBamNoiDung,
                    StringComparison.OrdinalIgnoreCase),
                contract.MaBamTepPdf,
                maBamTepPdfHopLe = pdfHashIsValid,
                noiDung = JsonSerializer.Deserialize<JsonElement>(contract.NoiDungHopDongJson)
            });
        });

        contracts.MapPost("/{id}/huy", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            
            if (contract.TrangThai == "DA_HUY")
                return Results.Ok(new { contract.MaHopDong, contract.TrangThai });

            var hasPayment = await db.ThanhToan.AnyAsync(x => x.MaHopDong == id && (x.TrangThai == "THANH_CONG" || x.TrangThai == "CHO_THANH_TOAN"), ct);
            if (hasPayment) return Results.Conflict(new { loi = "Hợp đồng đã có thanh toán hoặc giao dịch đang xử lý, không thể tự hủy." });

            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Chỉ được tự hủy hợp đồng đang chờ ký." });
            
            contract.TrangThai = "DA_HUY";

            // Cleanup ChiTietGioHang neu thuoc THUE_NGAY
            var holdLines = await db.ChiTietGiuCho.Where(x => x.MaGiuCho == contract.MaGiuCho).ToListAsync(ct);
            var cartLineIds = holdLines.Where(x => x.MaChiTietGioHang != null).Select(x => x.MaChiTietGioHang).ToList();
            if (cartLineIds.Any())
            {
                var cartLines = await db.ChiTietGioHang
                    .Where(x => cartLineIds.Contains(x.MaChiTietGioHang) && x.NguonTao == "THUE_NGAY")
                    .ToListAsync(ct);
                
                if (cartLines.Any())
                {
                    foreach(var line in cartLines)line.DaChuyenHopDong=true;
                }
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new { contract.MaHopDong, contract.TrangThai });
        }).RequireAuthorization("Customer");

        contracts.MapPut("/{id}/thiet-bi", async (
            string id, PrepareDevicesRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.MaThietBi.Count == 0 ||
                request.MaThietBi.Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.MaThietBi.Count)
                return Results.BadRequest(new { loi = "Danh sách thiết bị trống hoặc bị trùng." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict(new{loi="Hợp đồng được bảo toàn."});
            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (contract.TrangThai != "DA_KY")
                return Results.Conflict(new { loi = "Hợp đồng chưa ký hoặc đã qua bước chuẩn bị thiết bị." });
            if (await db.ChiTietHopDong.AnyAsync(x => x.MaHopDong == id, ct))
                return Results.Conflict(new { loi = "Hợp đồng đã được gán thiết bị." });

            var booked = await db.ChiTietGiuCho.AsNoTracking().Where(x => x.MaGiuCho == contract.MaGiuCho)
                .ToListAsync(ct);
            var devices = await db.ThietBi.Where(x => request.MaThietBi.Contains(x.MaThietBi)).ToListAsync(ct);
            if (devices.Count != request.MaThietBi.Count)
                return Results.NotFound(new { loi = "Có mã thiết bị không tồn tại." });
            if (devices.Any(x => x.MaCuaHang != contract.MaCuaHang || x.TrangThai != "SAN_SANG"))
                return Results.Conflict(new { loi = "Thiết bị không cùng cửa hàng hoặc không ở trạng thái SAN_SANG." });

            foreach (var line in booked.GroupBy(x=>x.MaDongMay).Select(g=>new{MaDongMay=g.Key,SoLuong=g.Sum(x=>x.SoLuong)}))
            {
                var selected = devices.Where(x => x.MaDongMay == line.MaDongMay).ToList();
                if (selected.Count != line.SoLuong)
                    return Results.Conflict(new
                    {
                        loi = $"Dòng máy {line.MaDongMay} cần đúng {line.SoLuong} thiết bị vật lý."
                    });
            }
            if (devices.Any(x => booked.All(b => b.MaDongMay != x.MaDongMay)))
                return Results.Conflict(new { loi = "Danh sách có thiết bị không thuộc dòng máy đã đặt." });

            var deviceIds = devices.Select(x => x.MaThietBi).ToList();
            var overlap = await db.ChiTietHopDong.AsNoTracking().AnyAsync(c =>
                deviceIds.Contains(c.MaThietBi) && c.MaHopDong != id &&
                (c.MaBienBanNhanTra == null || c.NgayNhanThucTe == null || c.NgayNhanThucTe > contract.ThoiGianBanGiao) &&
                db.HopDong.Any(h => h.MaHopDong == c.MaHopDong &&
                    h.TrangThai != "HOAN_THANH" && h.TrangThai != "DA_HUY" &&
                    contract.ThoiGianBanGiao < (db.PhuLuc.Where(p=>p.MaHopDong==h.MaHopDong&&
                        (p.TrangThai=="DA_XAC_NHAN"||p.TrangThai=="DA_HIEU_LUC"||p.TrangThai=="CHO_KY"&&p.HanKyUtc>DateTime.UtcNow))
                        .Max(p=>(DateTime?)p.ThoiHanTraMoi)??h.ThoiGianTraDuKien) &&
                    contract.ThoiGianTraDuKien > h.ThoiGianBanGiao), ct);
            if (overlap) return Results.Conflict(new { loi = "Có thiết bị vật lý đã được gán cho lịch thuê khác." });

            var cartLines = await db.ChiTietGioHang.AsNoTracking()
                .Where(x => x.MaGioHang == contract.MaGioHang)
                .ToListAsync(ct);
            var prices = cartLines.GroupBy(x => x.MaDongMay)
                .ToDictionary(x => x.Key, x => x.First().DonGia);
            foreach (var device in devices)
            {
                device.TrangThai = "DANG_GIU";
                db.ChiTietHopDong.Add(new ChiTietHopDong
                {
                    MaChiTietHopDong = ApiAccess.NewId("CTH"), MaHopDong = id,
                    MaThietBi = device.MaThietBi, DonGia = prices[device.MaDongMay],
                    TinhTrangLucGiao = null, CoHuHong = false
                });
            }
            contract.MaNhanVien = scope.EmployeeId ?? await db.NhanVien.AsNoTracking()
                .Where(x => x.MaCuaHang == contract.MaCuaHang && x.TrangThai == "HOAT_DONG")
                .Select(x => x.MaNhanVien).FirstOrDefaultAsync(ct);
            if (contract.MaNhanVien is null)
                return Results.Conflict(new { loi = "Cửa hàng chưa có nhân viên phụ trách." });
            contract.TrangThai = "CHO_BAN_GIAO";
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new
            {
                contract.MaHopDong, contract.TrangThai,
                thietBi = devices.Select(x => new { x.MaThietBi, x.MaDongMay, x.SoSerial })
            });
        }).RequireAuthorization("Staff");

        contracts.MapPost("/{id}/thanh-toan-coc", async (
            string id, CreatePaymentRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, IOptions<BankTransferOptions> bankOptions, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var paymentMethod = request.PhuongThuc?.Trim().ToUpperInvariant();
            if (paymentMethod is not ("TIEN_MAT" or "CHUYEN_KHOAN" or "VI_DIEN_TU"))
                return Results.BadRequest(new { loi = "Phương thức thanh toán không hợp lệ." });
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai is "CHO_KY" or "DA_HUY" or "HOAN_THANH")
                return Results.Conflict(new { loi = "Trạng thái hợp đồng chưa cho phép thanh toán cọc." });
            var bank = bankOptions.Value;
            if (paymentMethod == "CHUYEN_KHOAN" && !bank.IsValid)
            {
                return Results.Problem("Cấu hình tài khoản ngân hàng thụ hưởng chưa đầy đủ hoặc không hợp lệ.", statusCode: StatusCodes.Status500InternalServerError);
            }

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            contract=await db.HopDong.AsNoTracking().SingleAsync(x=>x.MaHopDong==id,ct);
            if(RentalPolicy.ProtectedContracts.Contains(id)||contract.TrangThai is "CHO_KY" or "DA_HUY" or "HOAN_THANH")return Results.Conflict();
            if (await db.ThanhToan.AnyAsync(x => x.MaHopDong == id && x.LoaiThanhToan == "TIEN_COC" &&
                (x.TrangThai == "CHO_THANH_TOAN" || x.TrangThai == "THANH_CONG"), ct))
                return Results.Conflict(new { loi = "Khoản thanh toán cọc đã tồn tại." });

            var payment = new ThanhToan
            {
                MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id, SoTien = contract.TongTienCoc,
                LoaiThanhToan = "TIEN_COC", PhuongThuc = paymentMethod,
                TrangThai = "CHO_THANH_TOAN",
                NoiDungChuyenKhoan = string.IsNullOrWhiteSpace(request.NoiDungChuyenKhoan)
                    ? $"COC {contract.MaHopDong}"
                    : request.NoiDungChuyenKhoan.Trim(),
                MaNganHang = paymentMethod == "CHUYEN_KHOAN" ? bank.NganHang : null,
                MaThamChieu = null,
                DuongDanThanhToan = paymentMethod == "CHUYEN_KHOAN"
                    ? JsonSerializer.Serialize(new { nganHang = bank.NganHang, maBin = bank.MaBin, soTaiKhoan = bank.SoTaiKhoan, chuTaiKhoan = bank.ChuTaiKhoan })
                    : null
            };
            db.ThanhToan.Add(payment);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created($"/api/thanh-toan/{payment.MaThanhToan}", ToPaymentDto(payment, bank,
                paymentMethod == "TIEN_MAT"
                    ? "Đã tạo yêu cầu thanh toán tiền mặt; vui lòng chờ cửa hàng xác nhận."
                    : "Đã tạo giao dịch; vui lòng thanh toán theo nội dung chuyển khoản."));
        });

        contracts.MapGet("/{id}/thanh-toan", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db,
            IOptions<BankTransferOptions> bankOptions, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            if (!await db.HopDong.AsNoTracking().AnyAsync(x => x.MaHopDong == id, ct))
                return Results.NotFound();

            var data = await db.ThanhToan.AsNoTracking()
                .Where(x => x.MaHopDong == id)
                .OrderByDescending(x => x.ThoiGian)
                .ThenByDescending(x => x.MaThanhToan)
                .ToListAsync(ct);
            return Results.Ok(data.Select(p => ToPaymentDto(p, bankOptions.Value)));
        });

        var payments = app.MapGroup("/api/thanh-toan").RequireAuthorization();
        payments.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db,
            IOptions<BankTransferOptions> bankOptions, CancellationToken ct) =>
        {
            var payment = await db.ThanhToan.AsNoTracking().SingleOrDefaultAsync(x => x.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            if (!await ApiAccess.CanAccessContractAsync(payment.MaHopDong, principal, db, ct)) return Results.Forbid();
            return Results.Ok(ToPaymentDto(payment, bankOptions.Value));
        });

        payments.MapPost("/{id}/xac-nhan", async (
            string id, ConfirmPaymentRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var parent=await db.ThanhToan.AsNoTracking().Where(t=>t.MaThanhToan==id).Select(t=>t.MaHopDong).SingleOrDefaultAsync(ct);
            if(parent is null)return Results.NotFound();
            if(RentalPolicy.ProtectedContracts.Contains(parent))return Results.Conflict();
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"contract:"+parent,ct);
            var payment = await db.ThanhToan.Join(db.HopDong, t => t.MaHopDong, h => h.MaHopDong, (t, h) => new { t, h })
                .SingleOrDefaultAsync(x => x.t.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            if (!scope.IsAdmin && payment.h.MaCuaHang != scope.StoreId) return Results.Forbid();
            if(payment.t.LoaiThanhToan.StartsWith("HOAN_"))return Results.Conflict(new{loi="Khoản hoàn dùng endpoint xác nhận đã hoàn riêng; không ghi thu thành công."});
            if(payment.t.LoaiThanhToan.StartsWith("HOAN_"))return Results.Conflict(new{loi="Khoản hoàn cần API ghi hoàn và Customer xác nhận; không dùng xác nhận thu."});
            if(payment.t.MaQuyetToan != null)return Results.Conflict(new{loi="Khoản thu quyết toán cần kết quả VNPAY đã xác thực, không xác nhận thủ công hoặc đổi sang tiền mặt."});
            if(await db.QuyetToanHopDong.AnyAsync(q=>q.MaHopDong==parent,ct)) {
                var settlement=await RentalCamera.Api.Settlement.SettlementWorkflow.LoadAsync(parent,db,ct);
                if(settlement?.Final is not {} final || payment.t.MaQuyetToan!=final.Id || payment.t.LoaiThanhToan!="THU_QUYET_TOAN" ||
                    settlement.Contract.TrangThai!="CHO_HOAN_TRA" || RentalCamera.Api.Settlement.SettlementWorkflow.FinancialMismatch(settlement) ||
                    payment.t.SoTien!=final.ConPhaiThuBanDau-RentalCamera.Api.Settlement.SettlementWorkflow.Collected(settlement))
                    return Results.Conflict(new{loi="Khoản thu không khớp quyết toán đã chốt; cần đối soát."});
            }
            if (payment.t.TrangThai != "CHO_THANH_TOAN")
                return Results.Conflict(new { loi = "Giao dịch đã được xử lý." });
            if (request.ThanhCong && payment.t.PhuongThuc != "TIEN_MAT" &&
                string.IsNullOrWhiteSpace(request.MaGiaoDich))
                return Results.BadRequest(new { loi = "Mã giao dịch là bắt buộc khi xác nhận thanh toán không dùng tiền mặt." });
            payment.t.TrangThai = request.ThanhCong ? "THANH_CONG" : "THAT_BAI";
            payment.t.MaGiaoDich = request.MaGiaoDich?.Trim();
            payment.t.ThoiGian = RentalPolicy.LocalNow;
            if(request.ThanhCong) {
                var cancellation=await db.DoiSoatHuyHopDong.SingleOrDefaultAsync(x=>x.MaHopDong==parent,ct);
                if(cancellation is not null)await CancellationEndpoints.ReconcileAsync(cancellation,db,ct,true);
            }
            await db.SaveChangesAsync(ct);
            await RentalCamera.Api.Settlement.SettlementWorkflow.ReconcileAsync(parent, db, ct);
            await tx.CommitAsync(ct);
            return Results.Ok(payment.t);
        }).RequireAuthorization("Staff");

    }

    private static string? GetClientIp(HttpContext context)
    {
        var value = context.Connection.RemoteIpAddress?.ToString();
        return string.IsNullOrWhiteSpace(value) ? null : value[..Math.Min(value.Length, 45)];
    }

    private static string? GetUserAgent(HttpContext context)
    {
        var value = context.Request.Headers.UserAgent.ToString();
        return string.IsNullOrWhiteSpace(value) ? null : value[..Math.Min(value.Length, 500)];
    }

    private static string? MaskEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return null;
        var at = email.IndexOf('@');
        if (at <= 0 || at == email.Length - 1) return "***";
        if (at == 1) return $"***{email[at..]}";
        return $"{email[0]}***{email[(at - 1)..]}";
    }

    private static async Task<string> BuildContractSnapshotAsync(
        HopDong contract, RentalCameraContext db, string termsVersion, CancellationToken ct)
    {
        var customer = await db.KhachThue.AsNoTracking()
            .Where(x => x.MaKhachThue == contract.MaKhachThue)
            .Select(x => new { x.MaKhachThue, x.HoTen, x.SoDienThoai, x.Email, x.CCCD, x.DiaChi })
            .SingleAsync(ct);
        var store = await db.CuaHang.AsNoTracking()
            .Where(x => x.MaCuaHang == contract.MaCuaHang)
            .Select(x => new { x.MaCuaHang, x.TenCuaHang, x.DiaChi, x.SoDienThoai, x.Email })
            .SingleAsync(ct);
        var items = await db.ChiTietGioHang.AsNoTracking()
            .Where(x => x.MaGioHang == contract.MaGioHang)
            .Join(db.DongMay.AsNoTracking(), x => x.MaDongMay, x => x.MaDongMay,
                (line, model) => new
                {
                    line.MaDongMay, model.TenDongMay, line.SoLuong,
                    line.NgayBatDau, line.NgayKetThuc,
                    line.DonGia, line.TienCoc, line.ThanhTien
                })
            .OrderBy(x => x.MaDongMay)
            .ToListAsync(ct);

        return JsonSerializer.Serialize(new
        {
            schemaVersion = "1.0",
            phienBanDieuKhoan = termsVersion,
            dieuKhoan = termsVersion == RentalPolicy.TermsVersion ? RentalPolicy.Terms : null,
            hopDong = new
            {
                contract.MaHopDong, contract.NgayTaoHopDong,
                contract.ThoiGianBanGiao, contract.ThoiGianTraDuKien,
                contract.TongTien, contract.TongTienCoc, contract.MaBamTepPdf
            },
            khachHang = customer,
            cuaHang = store,
            chiTietThue = items
        }, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });
    }

    private static object ToPaymentDto(ThanhToan p, BankTransferOptions bankOptions, string? thongBao = null)
    {
        string? nganHang = null;
        string? maBin = null;
        string? soTaiKhoan = null;
        string? chuTaiKhoan = null;

        if (p.PhuongThuc == "CHUYEN_KHOAN")
        {
            if (!string.IsNullOrWhiteSpace(p.DuongDanThanhToan) && p.DuongDanThanhToan.StartsWith("{"))
            {
                try
                {
                    using var doc = JsonDocument.Parse(p.DuongDanThanhToan);
                    var root = doc.RootElement;
                    if (root.TryGetProperty("nganHang", out var nh)) nganHang = nh.GetString();
                    if (root.TryGetProperty("maBin", out var mb)) maBin = mb.GetString();
                    if (root.TryGetProperty("soTaiKhoan", out var stk)) soTaiKhoan = stk.GetString();
                    if (root.TryGetProperty("chuTaiKhoan", out var ctk)) chuTaiKhoan = ctk.GetString();
                }
                catch
                {
                }
            }

            if (string.IsNullOrWhiteSpace(nganHang) && bankOptions.IsValid)
            {
                nganHang = bankOptions.NganHang;
                maBin = bankOptions.MaBin;
                soTaiKhoan = bankOptions.SoTaiKhoan;
                chuTaiKhoan = bankOptions.ChuTaiKhoan;
            }
        }

        return new
        {
            p.MaThanhToan,
            p.MaHopDong,
            p.SoTien,
            p.LoaiThanhToan,
            p.PhuongThuc,
            p.MaGiaoDich,
            p.ThoiGian,
            p.TrangThai,
            p.NoiDungChuyenKhoan,
            p.NhaCungCap,
            p.MaThamChieu,
            p.MaNganHang,
            p.LoaiThe,
            p.MaPhanHoi,
            p.DuongDanThanhToan,
            p.ThoiGianHetHan,
            p.ThoiGianCapNhat,
            nganHang,
            maBin,
            soTaiKhoan,
            chuTaiKhoan,
            thongBao
        };
    }

    public static bool IsIdentityVerifiedForRental(GiayToTuyThan document) =>
        string.Equals(document.TrangThaiXacMinh, "HOP_LE", StringComparison.Ordinal);
}

public sealed record RequestContractSignatureRequest(bool DaDongYDieuKhoan);
public sealed record SignContractRequest(
    string MaXacNhan,
    string MaOtp,
    bool DaDongYDieuKhoan);
public sealed record PrepareDevicesRequest(List<string> MaThietBi);
public sealed record CreatePaymentRequest(string? PhuongThuc, string? NoiDungChuyenKhoan);
public sealed record ConfirmPaymentRequest(bool ThanhCong, string? MaGiaoDich);
public sealed record ExtensionRequest(
    DateTime ThoiHanTraMoi,
    string? LyDoGiaHan,
    string? GhiChu);
public sealed record ProcessExtensionRequest(string QuyetDinh, string? GhiChu);
public sealed record ExtensionQuote(
    bool CoTheGiaHan,
    string? LyDo,
    DateTime ThoiHanTraHienTai,
    DateTime ThoiHanTraMoi,
    int SoNgayGiaHan,
    decimal ChiPhiDuKien);
