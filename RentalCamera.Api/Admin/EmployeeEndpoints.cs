using System.Net.Mail;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Admin;

public static class EmployeeEndpoints
{
    public static void MapEmployeeEndpoints(this IEndpointRouteBuilder app)
    {
        var employees = app.MapGroup("/api/nhan-vien")
            .RequireAuthorization("Admin");

        employees.MapGet("", async (
            RentalCameraContext db,
            string? tuKhoa,
            string? maCuaHang,
            string? trangThai,
            int? trang,
            int? kichThuocTrang,
            CancellationToken ct) =>
        {
            var page = Math.Max(trang ?? 1, 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = EmployeeQuery(db);

            if (!string.IsNullOrWhiteSpace(tuKhoa))
            {
                var keyword = tuKhoa.Trim();
                query = query.Where(x =>
                    x.HoTen.Contains(keyword) ||
                    x.TenDangNhap.Contains(keyword) ||
                    x.SoDienThoai.Contains(keyword) ||
                    (x.Email != null && x.Email.Contains(keyword)));
            }

            if (!string.IsNullOrWhiteSpace(maCuaHang))
            {
                var storeId = maCuaHang.Trim();
                query = query.Where(x => x.MaCuaHang == storeId);
            }

            if (!string.IsNullOrWhiteSpace(trangThai))
            {
                var state = trangThai.Trim().ToUpperInvariant();
                if (state is not ("HOAT_DONG" or "NGHI_VIEC"))
                    return Results.BadRequest(new { loi = "Trạng thái nhân viên không hợp lệ." });
                query = query.Where(x => x.TrangThaiNhanVien == state);
            }

            var total = await query.CountAsync(ct);
            var items = await query
                .OrderBy(x => x.HoTen)
                .ThenBy(x => x.MaNhanVien)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(x => new EmployeeResponse(
                    x.MaNhanVien,
                    x.MaTaiKhoan,
                    x.TenDangNhap,
                    x.TrangThaiTaiKhoan,
                    x.MaCuaHang,
                    x.TenCuaHang,
                    x.HoTen,
                    x.DiaChi,
                    x.SoDienThoai,
                    x.ChucVu,
                    x.Email,
                    x.TrangThaiNhanVien,
                    x.NgayTaoTaiKhoan))
                .ToListAsync(ct);

            return Results.Ok(new
            {
                trang = page,
                kichThuocTrang = pageSize,
                tongSo = total,
                duLieu = items
            });
        });

        employees.MapGet("/{id}", async (
            string id,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var employee = await EmployeeQuery(db)
                .Where(x => x.MaNhanVien == id)
                .Select(x => new EmployeeResponse(
                    x.MaNhanVien,
                    x.MaTaiKhoan,
                    x.TenDangNhap,
                    x.TrangThaiTaiKhoan,
                    x.MaCuaHang,
                    x.TenCuaHang,
                    x.HoTen,
                    x.DiaChi,
                    x.SoDienThoai,
                    x.ChucVu,
                    x.Email,
                    x.TrangThaiNhanVien,
                    x.NgayTaoTaiKhoan))
                .SingleOrDefaultAsync(ct);

            return employee is null ? Results.NotFound() : Results.Ok(employee);
        });

        employees.MapPost("", async (
            CreateEmployeeRequest request,
            RentalCameraContext db,
            IPasswordHasher<TaiKhoan> hasher,
            CancellationToken ct) =>
        {
            var validationError = ValidateEmployee(
                request.TenDangNhap,
                request.MatKhau,
                request.MaCuaHang,
                request.HoTen,
                request.DiaChi,
                request.SoDienThoai,
                request.ChucVu,
                request.Email,
                requirePassword: true);
            if (validationError is not null)
                return Results.BadRequest(new { loi = validationError });

            var username = request.TenDangNhap.Trim();
            var phone = request.SoDienThoai.Trim();
            var email = NormalizeOptional(request.Email);
            var storeId = request.MaCuaHang.Trim();

            if (!await db.CuaHang.AnyAsync(
                    x => x.MaCuaHang == storeId && x.TrangThai == "HOAT_DONG", ct))
                return Results.BadRequest(new { loi = "Cửa hàng không tồn tại hoặc đang tạm khóa." });

            if (await db.TaiKhoan.AnyAsync(x => x.TenDangNhap == username, ct))
                return Results.Conflict(new { loi = "Tên đăng nhập đã tồn tại." });
            if (await db.NhanVien.AnyAsync(x => x.SoDienThoai == phone, ct))
                return Results.Conflict(new { loi = "Số điện thoại nhân viên đã tồn tại." });
            if (email is not null && await db.NhanVien.AnyAsync(x => x.Email == email, ct))
                return Results.Conflict(new { loi = "Email nhân viên đã tồn tại." });

            var account = new TaiKhoan
            {
                MaTaiKhoan = ApiAccess.NewId("TK"),
                TenDangNhap = username,
                VaiTro = "NHAN_VIEN",
                TrangThai = "HOAT_DONG",
                NgayTao = DateTime.Now
            };
            account.MatKhauHash = hasher.HashPassword(account, request.MatKhau);

            var employee = new NhanVien
            {
                MaNhanVien = ApiAccess.NewId("NV"),
                MaTaiKhoan = account.MaTaiKhoan,
                MaCuaHang = storeId,
                HoTen = request.HoTen.Trim(),
                DiaChi = NormalizeOptional(request.DiaChi),
                SoDienThoai = phone,
                ChucVu = request.ChucVu.Trim(),
                Email = email,
                TrangThai = "HOAT_DONG"
            };

            db.TaiKhoan.Add(account);
            db.NhanVien.Add(employee);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                return Results.Conflict(new
                {
                    loi = "Không thể tạo nhân viên; hãy kiểm tra thông tin trùng lặp."
                });
            }

            var result = await EmployeeQuery(db)
                .Where(x => x.MaNhanVien == employee.MaNhanVien)
                .Select(x => new EmployeeResponse(
                    x.MaNhanVien,
                    x.MaTaiKhoan,
                    x.TenDangNhap,
                    x.TrangThaiTaiKhoan,
                    x.MaCuaHang,
                    x.TenCuaHang,
                    x.HoTen,
                    x.DiaChi,
                    x.SoDienThoai,
                    x.ChucVu,
                    x.Email,
                    x.TrangThaiNhanVien,
                    x.NgayTaoTaiKhoan))
                .SingleAsync(ct);

            return Results.Created($"/api/nhan-vien/{employee.MaNhanVien}", result);
        });

        employees.MapPut("/{id}", async (
            string id,
            UpdateEmployeeRequest request,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var validationError = ValidateEmployee(
                request.TenDangNhap,
                null,
                request.MaCuaHang,
                request.HoTen,
                request.DiaChi,
                request.SoDienThoai,
                request.ChucVu,
                request.Email,
                requirePassword: false);
            if (validationError is not null)
                return Results.BadRequest(new { loi = validationError });

            var employee = await db.NhanVien.SingleOrDefaultAsync(
                x => x.MaNhanVien == id, ct);
            if (employee is null) return Results.NotFound();

            var account = await db.TaiKhoan.SingleAsync(
                x => x.MaTaiKhoan == employee.MaTaiKhoan, ct);
            var username = request.TenDangNhap.Trim();
            var phone = request.SoDienThoai.Trim();
            var email = NormalizeOptional(request.Email);
            var storeId = request.MaCuaHang.Trim();

            if (!await db.CuaHang.AnyAsync(
                    x => x.MaCuaHang == storeId && x.TrangThai == "HOAT_DONG", ct))
                return Results.BadRequest(new { loi = "Cửa hàng không tồn tại hoặc đang tạm khóa." });
            if (await db.TaiKhoan.AnyAsync(
                    x => x.MaTaiKhoan != account.MaTaiKhoan && x.TenDangNhap == username, ct))
                return Results.Conflict(new { loi = "Tên đăng nhập đã tồn tại." });
            if (await db.NhanVien.AnyAsync(
                    x => x.MaNhanVien != id && x.SoDienThoai == phone, ct))
                return Results.Conflict(new { loi = "Số điện thoại nhân viên đã tồn tại." });
            if (email is not null && await db.NhanVien.AnyAsync(
                    x => x.MaNhanVien != id && x.Email == email, ct))
                return Results.Conflict(new { loi = "Email nhân viên đã tồn tại." });

            account.TenDangNhap = username;
            employee.MaCuaHang = storeId;
            employee.HoTen = request.HoTen.Trim();
            employee.DiaChi = NormalizeOptional(request.DiaChi);
            employee.SoDienThoai = phone;
            employee.ChucVu = request.ChucVu.Trim();
            employee.Email = email;

            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                return Results.Conflict(new
                {
                    loi = "Không thể cập nhật nhân viên; hãy kiểm tra thông tin trùng lặp."
                });
            }

            var result = await EmployeeQuery(db)
                .Where(x => x.MaNhanVien == id)
                .Select(x => new EmployeeResponse(
                    x.MaNhanVien,
                    x.MaTaiKhoan,
                    x.TenDangNhap,
                    x.TrangThaiTaiKhoan,
                    x.MaCuaHang,
                    x.TenCuaHang,
                    x.HoTen,
                    x.DiaChi,
                    x.SoDienThoai,
                    x.ChucVu,
                    x.Email,
                    x.TrangThaiNhanVien,
                    x.NgayTaoTaiKhoan))
                .SingleAsync(ct);

            return Results.Ok(result);
        });
    }

    private static IQueryable<EmployeeJoinRow> EmployeeQuery(RentalCameraContext db) =>
        from employee in db.NhanVien.AsNoTracking()
        join account in db.TaiKhoan.AsNoTracking()
            on employee.MaTaiKhoan equals account.MaTaiKhoan
        join store in db.CuaHang.AsNoTracking()
            on employee.MaCuaHang equals store.MaCuaHang
        select new EmployeeJoinRow
        {
            MaNhanVien = employee.MaNhanVien,
            MaTaiKhoan = employee.MaTaiKhoan,
            TenDangNhap = account.TenDangNhap,
            TrangThaiTaiKhoan = account.TrangThai,
            MaCuaHang = employee.MaCuaHang,
            TenCuaHang = store.TenCuaHang,
            HoTen = employee.HoTen,
            DiaChi = employee.DiaChi,
            SoDienThoai = employee.SoDienThoai,
            ChucVu = employee.ChucVu,
            Email = employee.Email,
            TrangThaiNhanVien = employee.TrangThai,
            NgayTaoTaiKhoan = account.NgayTao
        };

    private static string? ValidateEmployee(
        string? username,
        string? password,
        string? storeId,
        string? fullName,
        string? address,
        string? phone,
        string? title,
        string? email,
        bool requirePassword)
    {
        if (string.IsNullOrWhiteSpace(username) ||
            !Regex.IsMatch(username.Trim(), "^[a-zA-Z0-9_.-]{4,50}$"))
            return "Tên đăng nhập phải có 4–50 ký tự và chỉ gồm chữ, số, dấu chấm, gạch dưới hoặc gạch ngang.";
        if (requirePassword && !PasswordPolicy.IsValid(password))
            return PasswordPolicy.Description;
        if (string.IsNullOrWhiteSpace(storeId) || storeId.Trim().Length > 20)
            return "Mã cửa hàng không hợp lệ.";
        if (string.IsNullOrWhiteSpace(fullName) || fullName.Trim().Length > 150)
            return "Họ tên phải có từ 1 đến 150 ký tự.";
        if (!string.IsNullOrWhiteSpace(address) && address.Trim().Length > 500)
            return "Địa chỉ không được vượt quá 500 ký tự.";
        if (string.IsNullOrWhiteSpace(phone) ||
            !Regex.IsMatch(phone.Trim(), "^[0-9]{9,15}$"))
            return "Số điện thoại phải có từ 9 đến 15 chữ số.";
        if (string.IsNullOrWhiteSpace(title) || title.Trim().Length > 100)
            return "Chức vụ phải có từ 1 đến 100 ký tự.";
        if (!IsValidOptionalEmail(email))
            return "Email không hợp lệ hoặc vượt quá 255 ký tự.";
        return null;
    }

    private static bool IsValidOptionalEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return true;
        var value = email.Trim();
        if (value.Length > 255) return false;
        try
        {
            return new MailAddress(value).Address == value;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static string? NormalizeOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private sealed class EmployeeJoinRow
    {
        public string MaNhanVien { get; init; } = "";
        public string MaTaiKhoan { get; init; } = "";
        public string TenDangNhap { get; init; } = "";
        public string TrangThaiTaiKhoan { get; init; } = "";
        public string MaCuaHang { get; init; } = "";
        public string TenCuaHang { get; init; } = "";
        public string HoTen { get; init; } = "";
        public string? DiaChi { get; init; }
        public string SoDienThoai { get; init; } = "";
        public string ChucVu { get; init; } = "";
        public string? Email { get; init; }
        public string TrangThaiNhanVien { get; init; } = "";
        public DateTime NgayTaoTaiKhoan { get; init; }
    }
}

public sealed record CreateEmployeeRequest(
    string TenDangNhap,
    string MatKhau,
    string MaCuaHang,
    string HoTen,
    string? DiaChi,
    string SoDienThoai,
    string ChucVu,
    string? Email);

public sealed record UpdateEmployeeRequest(
    string TenDangNhap,
    string MaCuaHang,
    string HoTen,
    string? DiaChi,
    string SoDienThoai,
    string ChucVu,
    string? Email);

public sealed record EmployeeResponse(
    string MaNhanVien,
    string MaTaiKhoan,
    string TenDangNhap,
    string TrangThaiTaiKhoan,
    string MaCuaHang,
    string TenCuaHang,
    string HoTen,
    string? DiaChi,
    string SoDienThoai,
    string ChucVu,
    string? Email,
    string TrangThaiNhanVien,
    DateTime NgayTaoTaiKhoan);
