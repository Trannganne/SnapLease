using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Rental;

public static class RentalEndpoints
{
    public static void MapRentalEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/lich-trong", async (
            string maCuaHang, string maDongMay, DateTime ngayBatDau, DateTime ngayKetThuc,
            AvailabilityService availability, CancellationToken ct) =>
        {
            if (!ValidPeriod(ngayBatDau, ngayKetThuc))
                return Results.BadRequest(new { loi = "Thời gian thuê không hợp lệ; dùng giờ địa phương không kèm Z/múi giờ, tối đa 90 ngày." });
            var count = await availability.GetAvailableAsync(
                maCuaHang, maDongMay, ngayBatDau, ngayKetThuc, null, null, ct);
            return Results.Ok(new
            {
                maCuaHang, maDongMay, ngayBatDau, ngayKetThuc,
                soLuongConTrong = count
            });
        });

        app.MapGet("/api/lich-trong/thang", async (
            string maCuaHang, string maDongMay, int soLuong, int thang, int nam, string? maGiuCho,
            AvailabilityService availability, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(maCuaHang) || string.IsNullOrWhiteSpace(maDongMay) || soLuong is < 1 or > 10 || thang is < 1 or > 12 || nam < 2020)
                return Results.BadRequest(new { loi = "Tham số không hợp lệ." });
                
            if (!string.IsNullOrEmpty(maGiuCho))
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                if (customerId == null)
                    return Results.Unauthorized();
                
                var giuCho = await db.GiuCho.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.MaGiuCho == maGiuCho && x.MaKhachThue == customerId, ct);
                if (giuCho == null)
                    return Results.Forbid();
            }

            var monthStart = new DateTime(nam, thang, 1);
            var monthEnd = monthStart.AddMonths(1);
            
            // Allow looking up to 6 months ahead
            if (monthStart < new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1) || monthStart > DateTime.Now.AddMonths(6))
                return Results.BadRequest(new { loi = "Khoảng thời gian xem lịch không hợp lệ." });

            var list = await availability.GetMonthlyAvailabilityAsync(
                maCuaHang, maDongMay, soLuong, monthStart, monthEnd, maGiuCho, null, ct);
                
            return Results.Ok(new
            {
                maCuaHang, maDongMay, soLuong, thang, nam,
                thoiGianServer = DateTime.UtcNow,
                ngayList = list.Select(x => new
                {
                    ngay = x.Ngay.ToString("yyyy-MM-dd"),
                    soLuongKhaDungMin = x.SoLuongKhaDungMin,
                    trangThai = x.TrangThai
                })
            });
        });

        app.MapGet("/api/tam-tinh", async (
            string maCuaHang, string maDongMay, int soLuong, DateTime ngayBatDau, DateTime ngayKetThuc,
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(maCuaHang) || string.IsNullOrWhiteSpace(maDongMay) || soLuong is < 1 or > 10 ||
                !ValidPeriod(ngayBatDau, ngayKetThuc))
                return Results.BadRequest(new { loi = "Đầu vào hoặc thời gian thuê không hợp lệ." });
            
            if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == maCuaHang && x.TrangThai == "HOAT_DONG", ct))
                return Results.NotFound(new { loi = "Cửa hàng không tồn tại hoặc đang khóa." });

            var model = await db.DongMay.AsNoTracking().SingleOrDefaultAsync(x => x.MaDongMay == maDongMay, ct);
            if (model is null)
                return Results.NotFound(new { loi = "Dòng máy không tồn tại." });

            var quote = CalculatePrice(model, soLuong, ngayBatDau, ngayKetThuc);
            return Results.Ok(quote);
        });

        var holds = app.MapGroup("/api/giu-cho").RequireAuthorization("Customer");

        // 1. Khôi phục lượt (Mở lại app)
        holds.MapGet("/cua-toi/active", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            
            var now = DateTime.UtcNow;
            var activeHold = await db.GiuCho.AsNoTracking()
                .Include(x => x.ChiTiet)
                .Where(x => x.MaKhachThue == customerId && x.TrangThai == "DANG_GIU" && x.HetHanLuc > now)
                .OrderByDescending(x => x.HetHanLuc)
                .FirstOrDefaultAsync(ct);

            if (activeHold == null)
            {
                return Results.Ok(new { active = false });
            }

            var customer = await db.KhachThue.AsNoTracking().FirstOrDefaultAsync(x => x.MaKhachThue == customerId, ct);

            return Results.Ok(new
            {
                active = true,
                maGiuCho = activeHold.MaGiuCho,
                maGioHang = activeHold.MaGioHang,
                maCuaHang = activeHold.MaCuaHang,
                ngayTao = DateTime.SpecifyKind(activeHold.NgayTao, DateTimeKind.Utc),
                hetHanLuc = DateTime.SpecifyKind(activeHold.HetHanLuc, DateTimeKind.Utc),
                thoiGianServer = now,
                trangThai = activeHold.TrangThai,
                daXacNhanThongTin = customer?.DaXacNhanThongTin ?? false,
                chiTiet = activeHold.ChiTiet.Select(c => new
                {
                    c.MaChiTietGiuCho, c.MaDongMay, c.SoLuong, c.NgayBatDau, c.NgayKetThuc
                })
            });
        });

        // 2. Thuê ngay (Nguyên tử)
        holds.MapPost("/thue-ngay", async (
            [FromHeader(Name = "Idempotency-Key")] string idempotencyKey,
            [FromBody] ThueNgayRequest request, 
            ClaimsPrincipal principal, RentalCameraContext db,
            AvailabilityService availability, IConfiguration configuration, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(idempotencyKey))
                return Results.BadRequest(new { loi = "Thiếu Idempotency-Key." });

            if (string.IsNullOrWhiteSpace(request.MaCuaHang) || string.IsNullOrWhiteSpace(request.MaDongMay) ||
                request.SoLuong is < 1 or > 10 || !ValidPeriod(request.NgayBatDau, request.NgayKetThuc) ||
                request.NgayBatDau <= DateTime.Now)
                return Results.BadRequest(new { loi = "Thông tin thuê không hợp lệ." });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            // Tính PayloadHash để kiểm tra Idempotency
            var payloadStr = JsonSerializer.Serialize(new { request.MaCuaHang, request.MaDongMay, request.SoLuong, request.NgayBatDau, request.NgayKetThuc });
            var payloadHash = Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(payloadStr)));

            int retries = 3;
            while (retries > 0)
            {
                try 
                {
                    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

                    // Idempotency check
                    var existingKey = await db.IdempotencyKey
                        .FirstOrDefaultAsync(x => x.IdempotencyKey == idempotencyKey && x.MaKhachThue == customerId && x.LoaiThaoTac == "THUE_NGAY", ct);
                    
                    if (existingKey != null)
                    {
                        if (existingKey.PayloadHash != payloadHash)
                            return Results.Conflict(new { loi = "Idempotency-Key đã được sử dụng với payload khác." });

                        var existingHold = await db.GiuCho.Include(x => x.ChiTiet)
                            .FirstOrDefaultAsync(x => x.MaGiuCho == existingKey.MaThucThe, ct);
                        
                        if (existingHold == null) 
                            return Results.NotFound(new { loi = "Không tìm thấy giữ chỗ ban đầu." });

                        // Trả về kết quả cũ với trạng thái mới nhất
                        var customerCheck = await db.KhachThue.AsNoTracking().FirstOrDefaultAsync(x => x.MaKhachThue == customerId, ct);
                        return Results.Ok(new {
                            maGiuCho = existingHold.MaGiuCho,
                            chiTietIds = existingHold.ChiTiet.Select(x => x.MaChiTietGioHang).ToList(),
                            hetHanLuc = DateTime.SpecifyKind(existingHold.HetHanLuc, DateTimeKind.Utc),
                            thoiGianServer = DateTime.UtcNow,
                            trangThai = existingHold.HetHanLuc <= DateTime.UtcNow && existingHold.TrangThai == "DANG_GIU" ? "HET_HAN" : existingHold.TrangThai,
                            daXacNhanThongTin = customerCheck?.DaXacNhanThongTin ?? false
                        });
                    }

                    // Pre-checks
                    if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct))
                        return Results.NotFound(new { loi = "Cửa hàng không tồn tại hoặc đang khóa." });

                    var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == request.MaDongMay, ct);
                    if (model is null)
                        return Results.NotFound(new { loi = "Dòng máy không tồn tại." });

                    var available = await availability.GetAvailableAsync(request.MaCuaHang, request.MaDongMay,
                        request.NgayBatDau, request.NgayKetThuc, null, null, ct);
                    if (available < request.SoLuong)
                        return Results.Conflict(new
                        {
                            loi = "Không đủ thiết bị còn trống.",
                            soLuongConTrong = available
                        });

                    // Lấy hoặc tạo GioHang cho Khách
                    var cart = await db.GioHang
                        .Where(x => x.MaKhachThue == customerId)
                        .FirstOrDefaultAsync(ct);
                    
                    var now = DateTime.Now;
                    if (cart == null)
                    {
                        cart = new GioHang
                        {
                            MaGioHang = ApiAccess.NewId("GH"), MaKhachThue = customerId,
                            NgayTao = now, NgayCapNhat = now, TrangThai = "DANG_CHON"
                        };
                        db.GioHang.Add(cart);
                    }
                    else
                    {
                        cart.NgayCapNhat = now;
                    }

                    var cartLine = new ChiTietGioHang
                    {
                        MaChiTietGioHang = ApiAccess.NewId("CG"), 
                        MaGioHang = cart.MaGioHang,
                        MaCuaHang = request.MaCuaHang,
                        NguonTao = "THUE_NGAY"
                    };
                    ApplyServerPrice(cartLine, model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);
                    db.ChiTietGioHang.Add(cartLine);

                    var holdMinutes = Math.Clamp(configuration.GetValue("Rental:HoldMinutes", 20), 1, 120);
                    var utcNow = DateTime.UtcNow;
                    var hold = new GiuCho
                    {
                        MaGiuCho = ApiAccess.NewId("GC"), MaGioHang = cart.MaGioHang,
                        MaKhachThue = customerId, MaCuaHang = request.MaCuaHang,
                        NgayTao = utcNow, HetHanLuc = utcNow.AddMinutes(holdMinutes), TrangThai = "DANG_GIU"
                    };
                    db.GiuCho.Add(hold);

                    var holdLine = new ChiTietGiuCho
                    {
                        MaChiTietGiuCho = ApiAccess.NewId("GC"), MaGiuCho = hold.MaGiuCho,
                        MaChiTietGioHang = cartLine.MaChiTietGioHang,
                        MaDongMay = cartLine.MaDongMay, SoLuong = cartLine.SoLuong,
                        NgayBatDau = cartLine.NgayBatDau, NgayKetThuc = cartLine.NgayKetThuc
                    };
                    db.ChiTietGiuCho.Add(holdLine);

                    db.IdempotencyKey.Add(new IdempotencyKeyRecord
                    {
                        IdempotencyKey = idempotencyKey, MaKhachThue = customerId,
                        LoaiThaoTac = "THUE_NGAY", PayloadHash = payloadHash,
                        MaThucThe = hold.MaGiuCho, NgayTao = utcNow
                    });

                    await db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);

                    var customer = await db.KhachThue.AsNoTracking().FirstOrDefaultAsync(x => x.MaKhachThue == customerId, ct);
                    return Results.Created($"/api/giu-cho/{hold.MaGiuCho}", new
                    {
                        maGiuCho = hold.MaGiuCho, 
                        chiTietIds = new[] { cartLine.MaChiTietGioHang }, 
                        hetHanLuc = hold.HetHanLuc, 
                        thoiGianServer = utcNow, 
                        trangThai = hold.TrangThai, 
                        daXacNhanThongTin = customer?.DaXacNhanThongTin ?? false,
                        tongTienThue = cartLine.ThanhTien,
                        tienCoc = cartLine.TienCoc
                    });
                }
                catch (DbUpdateException)
                {
                    retries--;
                    if (retries == 0) throw;
                    db.ChangeTracker.Clear();
                    await Task.Delay(100, ct);
                }
            }
            return Results.StatusCode(500);
        });

        // 3. Tra cứu lượt cụ thể
        holds.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            
            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            
            if (hold is null) return Results.NotFound();
            
            if (hold.TrangThai == "DANG_GIU" && hold.HetHanLuc <= DateTime.UtcNow)
            {
                hold.TrangThai = "HET_HAN";
                await db.SaveChangesAsync(ct);
            }
            return Results.Ok(new
            {
                hold.MaGiuCho, hold.MaGioHang, hold.MaCuaHang, 
                ngayTao = DateTime.SpecifyKind(hold.NgayTao, DateTimeKind.Utc),
                hetHanLuc = DateTime.SpecifyKind(hold.HetHanLuc, DateTimeKind.Utc), 
                hold.TrangThai,
                chiTiet = hold.ChiTiet.Select(c => new
                {
                    c.MaChiTietGiuCho, c.MaDongMay, c.SoLuong, c.NgayBatDau, c.NgayKetThuc
                })
            });
        });

        // 3b. Cập nhật lượt giữ chỗ
        holds.MapPut("/{id}", async (
            string id, [FromBody] UpdateGiuChoRequest request,
            ClaimsPrincipal principal, RentalCameraContext db,
            AvailabilityService availability, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.MaCuaHang) || string.IsNullOrWhiteSpace(request.MaDongMay) ||
                request.SoLuong is < 1 or > 10 || !ValidPeriod(request.NgayBatDau, request.NgayKetThuc) ||
                request.NgayBatDau <= DateTime.Now)
                return Results.BadRequest(new { loi = "Thông tin cập nhật không hợp lệ." });

            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            try
            {
                await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

                    var hold = await db.GiuCho
                        .Include(x => x.ChiTiet)
                        .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);

                    if (hold is null) return Results.NotFound(new { loi = "Không tìm thấy giữ chỗ." });

                    if (hold.TrangThai != "DANG_GIU" || hold.HetHanLuc <= DateTime.UtcNow)
                        return Results.BadRequest(new { loi = "Giữ chỗ không còn hiệu lực để cập nhật." });

                    if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == request.MaCuaHang && x.TrangThai == "HOAT_DONG", ct))
                        return Results.NotFound(new { loi = "Cửa hàng mới không tồn tại hoặc đang khóa.", code = "BRANCH_NOT_FOUND" });

                    var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == request.MaDongMay, ct);
                    if (model is null) return Results.NotFound(new { loi = "Dòng máy không tồn tại." });

                    // Bỏ qua giữ chỗ hiện tại của chính nó khi kiểm tra số lượng trống
                    var available = await availability.GetAvailableAsync(request.MaCuaHang, request.MaDongMay,
                        request.NgayBatDau, request.NgayKetThuc, hold.MaGiuCho, null, ct);
                    if (available < request.SoLuong)
                        return Results.Conflict(new { loi = "Không đủ thiết bị còn trống tại chi nhánh và thời gian này.", code = "INSUFFICIENT_DEVICES" });

                    // Update GiuCho
                    hold.MaCuaHang = request.MaCuaHang;
                    
                    var holdLine = hold.ChiTiet.FirstOrDefault(x => x.MaDongMay == request.MaDongMay);
                    if (holdLine == null) return Results.BadRequest(new { loi = "Không tìm thấy chi tiết thiết bị trong giữ chỗ." });

                    holdLine.SoLuong = request.SoLuong;
                    holdLine.NgayBatDau = request.NgayBatDau;
                    holdLine.NgayKetThuc = request.NgayKetThuc;

                    // Update ChiTietGioHang
                    if (holdLine.MaChiTietGioHang != null)
                    {
                        var cartLine = await db.ChiTietGioHang.SingleOrDefaultAsync(x => x.MaChiTietGioHang == holdLine.MaChiTietGioHang, ct);
                        if (cartLine != null)
                        {
                            cartLine.MaCuaHang = request.MaCuaHang;
                            ApplyServerPrice(cartLine, model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);
                        }
                    }

                    await db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);

                    var customerCheck = await db.KhachThue.AsNoTracking().FirstOrDefaultAsync(x => x.MaKhachThue == customerId, ct);
                    var quote = CalculatePrice(model, request.SoLuong, request.NgayBatDau, request.NgayKetThuc);

                    return Results.Ok(new
                    {
                        maGiuCho = hold.MaGiuCho,
                        maCuaHang = hold.MaCuaHang,
                        hetHanLuc = DateTime.SpecifyKind(hold.HetHanLuc, DateTimeKind.Utc),
                        thoiGianServer = DateTime.UtcNow,
                        trangThai = hold.TrangThai,
                        daXacNhanThongTin = customerCheck?.DaXacNhanThongTin ?? false,
                        chiTiet = hold.ChiTiet.Select(c => new
                        {
                            c.MaChiTietGiuCho, c.MaDongMay, c.SoLuong, c.NgayBatDau, c.NgayKetThuc
                        }),
                        quote
                    });
                }
            catch (DbUpdateException)
            {
                // Xung đột đồng thời, giao dịch bị abort.
                // Loại bỏ vòng retry ngầm để tránh request cũ ghi đè request mới nếu có race condition,
                // trả lỗi conflict về Client để Frontend xử lý theo flow Timeout hoặc Reload.
                return Results.Conflict(new { loi = "Hệ thống đang bận cập nhật lượt giữ chỗ này, vui lòng thử lại." });
            }
        });


        // 4. Hủy lượt giữ chỗ
        holds.MapPost("/{id}/huy", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);

            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id && x.MaKhachThue == customerId, ct);
            
            if (hold is null) return Results.NotFound();

            if (hold.TrangThai == "DA_CHUYEN_HOP_DONG")
                return Results.Conflict(new { loi = "Giữ chỗ đã chuyển thành hợp đồng, không thể hủy." });
            if (hold.TrangThai == "DA_HUY")
                return Results.Ok(new { hold.MaGiuCho, hold.TrangThai });

            hold.TrangThai = hold.HetHanLuc <= DateTime.UtcNow ? "HET_HAN" : "DA_HUY";

            // Cleanup ChiTietGioHang neu thuoc THUE_NGAY
            var cartLineIds = hold.ChiTiet.Where(x => x.MaChiTietGioHang != null).Select(x => x.MaChiTietGioHang).ToList();
            if (cartLineIds.Any())
            {
                var cartLines = await db.ChiTietGioHang
                    .Where(x => cartLineIds.Contains(x.MaChiTietGioHang) && x.NguonTao == "THUE_NGAY")
                    .ToListAsync(ct);
                
                if (cartLines.Any())
                {
                    db.ChiTietGioHang.RemoveRange(cartLines);
                }
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new { hold.MaGiuCho, hold.TrangThai });
        });
    }

    public sealed record PriceQuote(
        string MaDongMay, int SoLuong, DateTime NgayBatDau, DateTime NgayKetThuc,
        int SoNgayTinhPhi, decimal GiaThueNgay, decimal PhanTramGiamGia, decimal DonGiaSauGiam,
        decimal TongTienThue, decimal TienCocMotDonVi, decimal TongTienCoc);

    private static PriceQuote CalculatePrice(DongMay model, int quantity, DateTime from, DateTime to)
    {
        var days = (int)Math.Ceiling((to - from).TotalDays);
        var unitPrice = Math.Round(model.GiaThueNgay * (100 - model.PhanTramGiamGia) / 100, 2);
        return new PriceQuote(
            model.MaDongMay, quantity, from, to, days,
            model.GiaThueNgay, model.PhanTramGiamGia, unitPrice,
            unitPrice * days * quantity, model.TienCoc, model.TienCoc * quantity
        );
    }

    private static void ApplyServerPrice(
        ChiTietGioHang item, DongMay model, int quantity, DateTime from, DateTime to)
    {
        var quote = CalculatePrice(model, quantity, from, to);
        item.MaDongMay = quote.MaDongMay;
        item.SoLuong = quote.SoLuong;
        item.NgayBatDau = quote.NgayBatDau;
        item.NgayKetThuc = quote.NgayKetThuc;
        item.DonGia = quote.DonGiaSauGiam;
        item.TienCoc = quote.TienCocMotDonVi;
        item.ThanhTien = quote.TongTienThue;
    }

    private static bool ValidPeriod(DateTime from, DateTime to) =>
        from.Kind == DateTimeKind.Unspecified && to.Kind == DateTimeKind.Unspecified &&
        to > from && to - from <= TimeSpan.FromDays(90);
}

public sealed record ThueNgayRequest(
    string MaCuaHang, string MaDongMay, int SoLuong,
    DateTime NgayBatDau, DateTime NgayKetThuc);

public sealed record UpdateGiuChoRequest(
    string MaCuaHang, string MaDongMay, int SoLuong,
    DateTime NgayBatDau, DateTime NgayKetThuc);
