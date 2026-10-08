using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Contracts;

public static class ContractEndpoints
{
    public static void MapContractEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/giu-cho/{id}/xac-nhan-thue", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
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
            if (await db.HopDong.AnyAsync(x => x.MaGiuCho == id || x.MaGioHang == hold.MaGioHang, ct))
                return Results.Conflict(new { loi = "Giữ chỗ hoặc giỏ hàng đã được chuyển thành hợp đồng." });
            if (!await db.GiayToTuyThan.AnyAsync(x =>
                    x.MaKhachThue == customerId && x.TrangThaiXacMinh == "HOP_LE", ct))
                return Results.Conflict(new { loi = "Khách hàng chưa có giấy tờ được xác minh." });

            var cart = await db.GioHang.Include(x => x.ChiTiet)
                .SingleAsync(x => x.MaGioHang == hold.MaGioHang, ct);
            var modelIds = hold.ChiTiet.Select(x => x.MaDongMay).ToList();
            var models = await db.DongMay.Where(x => modelIds.Contains(x.MaDongMay))
                .ToDictionaryAsync(x => x.MaDongMay, ct);
            if (models.Count != modelIds.Count)
                return Results.Conflict(new { loi = "Dữ liệu dòng máy trong giữ chỗ không còn hợp lệ." });

            decimal total = 0;
            decimal deposit = 0;
            foreach (var line in hold.ChiTiet)
            {
                var model = models[line.MaDongMay];
                var days = (decimal)Math.Ceiling((line.NgayKetThuc - line.NgayBatDau).TotalDays);
                var unitPrice = Math.Round(model.GiaThueNgay * (100 - model.PhanTramGiamGia) / 100, 2);
                total += unitPrice * days * line.SoLuong;
                deposit += model.TienCoc * line.SoLuong;

                var cartLine = cart.ChiTiet.SingleOrDefault(x => x.MaDongMay == line.MaDongMay);
                if (cartLine is not null)
                {
                    cartLine.DonGia = unitPrice;
                    cartLine.TienCoc = model.TienCoc;
                    cartLine.ThanhTien = unitPrice * days * line.SoLuong;
                }
            }

            var contract = new HopDong
            {
                MaHopDong = ApiAccess.NewId("HD"), MaGioHang = cart.MaGioHang,
                MaGiuCho = hold.MaGiuCho, MaKhachThue = customerId,
                MaNhanVien = null, MaCuaHang = hold.MaCuaHang,
                NgayTaoHopDong = DateTime.Now, NgayKy = null,
                ThoiGianBanGiao = hold.ChiTiet.Min(x => x.NgayBatDau),
                ThoiGianTraDuKien = hold.ChiTiet.Max(x => x.NgayKetThuc),
                TongTien = total, TongTienCoc = deposit,
                HinhThucKy = null, TrangThai = "CHO_KY", TepHopDongUrl = null
            };
            db.HopDong.Add(contract);
            hold.TrangThai = "DA_CHUYEN_HOP_DONG";
            cart.TrangThai = "DA_CHUYEN_HOP_DONG";
            cart.NgayCapNhat = DateTime.Now;

            var accountId = await db.KhachThue.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .Select(x => x.MaTaiKhoan).SingleAsync(ct);
            ApiAccess.AddNotification(db, accountId, "HOP_DONG", "Hợp đồng chờ ký",
                $"Hợp đồng {contract.MaHopDong} đã được tạo và đang chờ ký.");

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Created($"/api/hop-dong/{contract.MaHopDong}", new
            {
                contract.MaHopDong, contract.MaGiuCho, contract.TongTien,
                contract.TongTienCoc, contract.TrangThai, contract.NgayTaoHopDong
            });
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
                    x.TongTien, x.TongTienCoc, x.TrangThai
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");

        contracts.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();

            var booked = await db.ChiTietGiuCho.AsNoTracking().Where(x => x.MaGiuCho == contract.MaGiuCho)
                .Select(x => new { x.MaDongMay, x.SoLuong, x.NgayBatDau, x.NgayKetThuc }).ToListAsync(ct);
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
            var supplements = await db.PhuLuc.AsNoTracking().Where(x => x.MaHopDong == id)
                .OrderBy(x => x.NgayLap).ToListAsync(ct);

            return Results.Ok(new
            {
                contract.MaHopDong, contract.MaGioHang, contract.MaGiuCho,
                contract.MaKhachThue, contract.MaNhanVien, contract.MaCuaHang,
                contract.NgayTaoHopDong, contract.NgayKy,
                contract.ThoiGianBanGiao, contract.ThoiGianTraDuKien,
                contract.TongTien, contract.TongTienCoc, contract.HinhThucKy,
                contract.TrangThai, contract.TepHopDongUrl,
                DatTheoDongMay = booked, ChiTiet = details,
                ThanhToan = payments, PhuLuc = supplements
            });
        });

        contracts.MapPut("/{id}/ky", async (
            string id, SignContractRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, IConfiguration configuration, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            if (request.HinhThucKy is not ("DIEN_TU" or "MAN_HINH" or "BAN_GIAY"))
                return Results.BadRequest(new { loi = "Hình thức ký không hợp lệ." });
            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Hợp đồng không ở trạng thái chờ ký." });
            var timeout = Math.Clamp(configuration.GetValue("Rental:ContractSignMinutes", 30), 1, 1440);
            if (contract.NgayTaoHopDong.AddMinutes(timeout) <= DateTime.Now)
            {
                contract.TrangThai = "DA_HUY";
                await db.SaveChangesAsync(ct);
                return Results.Conflict(new { loi = "Hợp đồng đã quá thời hạn ký và đã bị hủy." });
            }
            contract.NgayKy = DateTime.Now;
            contract.HinhThucKy = request.HinhThucKy;
            contract.TepHopDongUrl = request.TepHopDongUrl?.Trim();
            contract.TrangThai = "DA_KY";
            await db.SaveChangesAsync(ct);
            return Results.Ok(new
            {
                contract.MaHopDong, contract.NgayKy, contract.HinhThucKy,
                contract.TrangThai, contract.TepHopDongUrl
            });
        });

        contracts.MapPost("/{id}/huy", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "CHO_KY")
                return Results.Conflict(new { loi = "Chỉ được tự hủy hợp đồng đang chờ ký." });
            contract.TrangThai = "DA_HUY";
            await db.SaveChangesAsync(ct);
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

            foreach (var line in booked)
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
                db.HopDong.Any(h => h.MaHopDong == c.MaHopDong &&
                    h.TrangThai != "HOAN_THANH" && h.TrangThai != "DA_HUY" &&
                    contract.ThoiGianBanGiao < h.ThoiGianTraDuKien &&
                    contract.ThoiGianTraDuKien > h.ThoiGianBanGiao), ct);
            if (overlap) return Results.Conflict(new { loi = "Có thiết bị vật lý đã được gán cho lịch thuê khác." });

            var prices = await db.ChiTietGioHang.AsNoTracking()
                .Where(x => x.MaGioHang == contract.MaGioHang)
                .ToDictionaryAsync(x => x.MaDongMay, x => x.DonGia, ct);
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
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            if (request.PhuongThuc is not ("TIEN_MAT" or "CHUYEN_KHOAN" or "VI_DIEN_TU"))
                return Results.BadRequest(new { loi = "Phương thức thanh toán không hợp lệ." });
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai is "CHO_KY" or "DA_HUY" or "HOAN_THANH")
                return Results.Conflict(new { loi = "Trạng thái hợp đồng chưa cho phép thanh toán cọc." });
            if (await db.ThanhToan.AnyAsync(x => x.MaHopDong == id && x.LoaiThanhToan == "TIEN_COC" &&
                (x.TrangThai == "CHO_THANH_TOAN" || x.TrangThai == "THANH_CONG"), ct))
                return Results.Conflict(new { loi = "Khoản thanh toán cọc đã tồn tại." });
            var payment = new ThanhToan
            {
                MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id, SoTien = contract.TongTienCoc,
                LoaiThanhToan = "TIEN_COC", PhuongThuc = request.PhuongThuc,
                TrangThai = "CHO_THANH_TOAN", NoiDungChuyenKhoan = request.NoiDungChuyenKhoan?.Trim()
            };
            db.ThanhToan.Add(payment);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/thanh-toan/{payment.MaThanhToan}", payment);
        });

        contracts.MapPost("/{id}/yeu-cau-gia-han", async (
            string id, ExtensionRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, AvailabilityService availability, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai is not ("DA_KY" or "CHO_BAN_GIAO" or "DANG_THUE") ||
                request.ThoiHanTraMoi <= contract.ThoiGianTraDuKien)
                return Results.Conflict(new { loi = "Thời hạn gia hạn không hợp lệ." });
            if (await db.PhuLuc.AnyAsync(x => x.MaHopDong == id && x.TrangThai == "CHO_XAC_NHAN", ct))
                return Results.Conflict(new { loi = "Đã có yêu cầu gia hạn đang chờ xử lý." });
            var booked = await db.ChiTietGiuCho.AsNoTracking().Where(x => x.MaGiuCho == contract.MaGiuCho).ToListAsync(ct);
            foreach (var line in booked)
            {
                var available = await availability.GetAvailableAsync(contract.MaCuaHang, line.MaDongMay,
                    line.NgayBatDau, request.ThoiHanTraMoi, null, contract.MaHopDong, ct);
                if (available < line.SoLuong)
                    return Results.Conflict(new { loi = $"Thời hạn mới trùng lịch của dòng máy {line.MaDongMay}." });
            }
            var extension = new PhuLuc
            {
                MaPhuLuc = ApiAccess.NewId("PL"), MaHopDong = id, NgayLap = DateTime.Now,
                ThoiHanTraMoi = request.ThoiHanTraMoi, ChiPhiPhatSinh = request.ChiPhiPhatSinh,
                TienCocBoSung = request.TienCocBoSung, LyDoGiaHan = request.LyDoGiaHan?.Trim(),
                GhiChu = request.GhiChu?.Trim(), TrangThai = "CHO_XAC_NHAN"
            };
            db.PhuLuc.Add(extension);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/gia-han/{extension.MaPhuLuc}", extension);
        }).RequireAuthorization("Customer");

        var payments = app.MapGroup("/api/thanh-toan").RequireAuthorization();
        payments.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var payment = await db.ThanhToan.AsNoTracking().SingleOrDefaultAsync(x => x.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            if (!await ApiAccess.CanAccessContractAsync(payment.MaHopDong, principal, db, ct)) return Results.Forbid();
            return Results.Ok(payment);
        });

        payments.MapPost("/{id}/xac-nhan", async (
            string id, ConfirmPaymentRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var payment = await db.ThanhToan.Join(db.HopDong, t => t.MaHopDong, h => h.MaHopDong, (t, h) => new { t, h })
                .SingleOrDefaultAsync(x => x.t.MaThanhToan == id, ct);
            if (payment is null) return Results.NotFound();
            if (!scope.IsAdmin && payment.h.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (payment.t.TrangThai != "CHO_THANH_TOAN")
                return Results.Conflict(new { loi = "Giao dịch đã được xử lý." });
            payment.t.TrangThai = request.ThanhCong ? "THANH_CONG" : "THAT_BAI";
            payment.t.MaGiaoDich = request.MaGiaoDich?.Trim();
            payment.t.ThoiGian = DateTime.Now;
            await db.SaveChangesAsync(ct);
            return Results.Ok(payment.t);
        }).RequireAuthorization("Staff");

        var extensions = app.MapGroup("/api/gia-han").RequireAuthorization("Staff");
        extensions.MapGet("/cho-duyet", async (
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.PhuLuc.AsNoTracking().Where(x => x.TrangThai == "CHO_XAC_NHAN")
                .Join(db.HopDong, p => p.MaHopDong, h => h.MaHopDong, (p, h) => new { p, h });
            if (!scope.IsAdmin) query = query.Where(x => x.h.MaCuaHang == scope.StoreId);
            return Results.Ok(await query.OrderBy(x => x.p.NgayLap).Select(x => new
            {
                x.p.MaPhuLuc, x.p.MaHopDong, x.h.MaCuaHang, x.p.NgayLap,
                x.p.ThoiHanTraMoi, x.p.ChiPhiPhatSinh, x.p.TienCocBoSung, x.p.LyDoGiaHan
            }).ToListAsync(ct));
        });

        extensions.MapPut("/{id}/xu-ly", async (
            string id, ProcessExtensionRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, AvailabilityService availability, CancellationToken ct) =>
        {
            if (request.QuyetDinh is not ("DUYET" or "TU_CHOI"))
                return Results.BadRequest(new { loi = "Quyết định phải là DUYET hoặc TU_CHOI." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var row = await db.PhuLuc.Join(db.HopDong, p => p.MaHopDong, h => h.MaHopDong, (p, h) => new { p, h })
                .SingleOrDefaultAsync(x => x.p.MaPhuLuc == id, ct);
            if (row is null) return Results.NotFound();
            if (!scope.IsAdmin && row.h.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (row.p.TrangThai != "CHO_XAC_NHAN")
                return Results.Conflict(new { loi = "Yêu cầu đã được xử lý." });

            if (request.QuyetDinh == "DUYET")
            {
                var booked = await db.ChiTietGiuCho.AsNoTracking()
                    .Where(x => x.MaGiuCho == row.h.MaGiuCho).ToListAsync(ct);
                foreach (var line in booked)
                {
                    var available = await availability.GetAvailableAsync(row.h.MaCuaHang, line.MaDongMay,
                        line.NgayBatDau, row.p.ThoiHanTraMoi, null, row.h.MaHopDong, ct);
                    if (available < line.SoLuong)
                        return Results.Conflict(new { loi = $"Không thể duyệt: dòng máy {line.MaDongMay} đã trùng lịch." });
                }
                row.p.TrangThai = "DA_XAC_NHAN";
            }
            else row.p.TrangThai = "TU_CHOI";

            if (!string.IsNullOrWhiteSpace(request.GhiChu)) row.p.GhiChu = request.GhiChu.Trim();
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(row.p);
        });
    }
}

public sealed record SignContractRequest(string HinhThucKy, string? TepHopDongUrl);
public sealed record PrepareDevicesRequest(List<string> MaThietBi);
public sealed record CreatePaymentRequest(string PhuongThuc, string? NoiDungChuyenKhoan);
public sealed record ConfirmPaymentRequest(bool ThanhCong, string? MaGiaoDich);
public sealed record ExtensionRequest(
    DateTime ThoiHanTraMoi, decimal ChiPhiPhatSinh, decimal TienCocBoSung,
    string? LyDoGiaHan, string? GhiChu);
public sealed record ProcessExtensionRequest(string QuyetDinh, string? GhiChu);
