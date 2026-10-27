#if !DIRECT_OFFLINE
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using System.Text.Json;
using RentalCamera.Api.Data;

public static class Schema33EfChecks
{
    private static readonly HashSet<string> ExpectedTables = new(StringComparer.Ordinal)
    {
        "dbo.TaiKhoan", "dbo.KhachThue", "dbo.NhanVien", "dbo.GiayToTuyThan",
        "dbo.DanhMuc", "dbo.ThuongHieu", "dbo.DongMay", "dbo.ThietBi", "dbo.AnhThietBi", "dbo.CuaHang",
        "dbo.GioHang", "dbo.ChiTietGioHang", "dbo.GiuCho", "dbo.ChiTietGiuCho",
        "dbo.HopDong", "dbo.ChiTietHopDong", "dbo.PhuLuc", "dbo.XacNhanKyHopDong",
        "dbo.ThanhToan", "dbo.YeuCauThanhToanVnpay", "dbo.PhieuPhat",
        "dbo.QuyetToanHopDong", "dbo.PhanBoQuyetToan",
        "dbo.DanhGia", "dbo.AnhDanhGia", "dbo.AnhBienBan",
        "dbo.ThongBao", "dbo.FcmDeviceToken", "dbo.NotificationDelivery", "dbo.IdempotencyKey",
        "dbo.BienBanNhanTra", "dbo.DoiSoatHuyHopDong", "dbo.XacMinhKhachKhongDen"
    };

    public static void Run(string? outputDirectory = null)
    {
        using var db = new RentalCameraContext(new DbContextOptionsBuilder<RentalCameraContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=OFFLINE_MODEL_ONLY;Integrated Security=true;TrustServerCertificate=true").Options);
        var entities = db.Model.GetEntityTypes().ToArray();
        var actualTables = entities.Where(e => e.GetTableName() != null)
            .Select(e => $"{e.GetSchema() ?? db.Model.GetDefaultSchema() ?? "dbo"}.{e.GetTableName()}")
            .ToHashSet(StringComparer.Ordinal);
        if (ExpectedTables.Count != 33 || !actualTables.SetEquals(ExpectedTables))
            throw new Exception("EF physical table set mismatch. Missing: " +
                string.Join(",", ExpectedTables.Except(actualTables)) + "; unexpected: " +
                string.Join(",", actualTables.Except(ExpectedTables)));
        if (entities.Sum(e => e.GetProperties().Count()) != 376)
            throw new Exception("EF scalar mapping differs from reviewed376 fields");
        if (entities.Any(e => e.GetProperties().Any(p => p.IsShadowProperty())))
            throw new Exception("Unexpected shadow relationship/property");
        var hold = entities.Single(e => e.GetTableName() == "ChiTietGiuCho" && (e.GetSchema() ?? "dbo") == "dbo");
        if (hold.FindProperty("MaChiTietGioHangHopDong") == null || hold.FindProperty("MaChiTietGioHang")!.IsNullable)
            throw new Exception("Hold original/snapshot linkage mismatch");
        var sql = db.Database.GenerateCreateScript(); // String generation only; never execute DDL.
        if (outputDirectory != null)
        {
            Directory.CreateDirectory(outputDirectory);
            File.WriteAllText(Path.Combine(outputDirectory, "ef-create.sql"), sql);
            var model = db.GetService<IDesignTimeModel>().Model.GetRelationalModel();
            var tables = model.Tables.Select(t => new {
                schema = t.Schema ?? "dbo", name = t.Name,
                columns = t.Columns.Select(c => new { name = c.Name, type = c.StoreType, nullable = c.IsNullable }),
                keys = t.UniqueConstraints.Select(k => new { name = k.Name, columns = k.Columns.Select(c => c.Name), primary = k == t.PrimaryKey }),
                indexes = t.Indexes.Select(i => new { name = i.Name, columns = i.Columns.Select(c => c.Name), unique = i.IsUnique, filter = i.Filter }),
                foreignKeys = t.ForeignKeyConstraints.Select(f => new { name = f.Name, columns = f.Columns.Select(c => c.Name), principalTable = f.PrincipalTable.Name, principalColumns = f.PrincipalColumns.Select(c => c.Name), deleteAction = f.OnDeleteAction.ToString() }),
                checks = t.CheckConstraints.Select(c => new { name = c.Name, sql = c.Sql })
            });
            File.WriteAllText(Path.Combine(outputDirectory, "ef-model.json"), JsonSerializer.Serialize(tables, new JsonSerializerOptions { WriteIndented = true }));
        }
        if (!sql.Contains("'DA_XAC_NHAN','DA_THANH_TOAN','HUY'"))
            throw new Exception("Valid paid penalty rejected");
        if (entities.SelectMany(e => e.GetForeignKeys()).Any(f => f.DeleteBehavior != DeleteBehavior.NoAction))
            throw new Exception("Unexpected cascade");
        Console.WriteLine("PASS EF exact33 schema.table set,376 scalar/no shadows and restrictive FKs; no database connected.");
    }
}
#endif
