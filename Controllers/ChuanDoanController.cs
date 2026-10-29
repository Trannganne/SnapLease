using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using RentalCamera.Data;
using System.Data;

namespace RentalCamera.Controllers;

// Chỉ dành cho Admin trong môi trường Development.
public class ChuanDoanController : BaseController
{
    private readonly RentalCameraDbContext _db;
    private readonly IWebHostEnvironment _environment;

    public ChuanDoanController(RentalCameraDbContext db, IWebHostEnvironment environment)
    {
        _db = db;
        _environment = environment;
    }

    protected override string[] GetAllowedRoles() => new[] { "ADMIN" };

    public async Task<IActionResult> Database()
    {
        if (!_environment.IsDevelopment()) return NotFound();
        var conn = _db.Database.GetDbConnection();
        try
        {
            if (conn.State != ConnectionState.Open) await conn.OpenAsync();
            var issues = new List<string>();
            var nullability = new List<string>();
            var missingTables = new List<string>();

            using (var identity = conn.CreateCommand())
            {
                identity.CommandText = "SELECT DB_NAME(), @@SERVERNAME";
                using var reader = await identity.ExecuteReaderAsync();
                await reader.ReadAsync();
                var database = reader.GetString(0);
                var server = reader.GetString(1);
                await reader.CloseAsync();

                foreach (var entity in _db.Model.GetEntityTypes())
                {
                    var table = entity.GetTableName();
                    if (table is null) continue;
                    var schema = entity.GetSchema() ?? "dbo";
                    var store = StoreObjectIdentifier.Table(table, schema);

                    using var columnsCmd = conn.CreateCommand();
                    columnsCmd.CommandText = @"SELECT COLUMN_NAME, IS_NULLABLE
                        FROM INFORMATION_SCHEMA.COLUMNS
                        WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table";
                    var ps = columnsCmd.CreateParameter(); ps.ParameterName = "@schema"; ps.Value = schema; columnsCmd.Parameters.Add(ps);
                    var pt = columnsCmd.CreateParameter(); pt.ParameterName = "@table"; pt.Value = table; columnsCmd.Parameters.Add(pt);
                    var columns = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
                    using (var columnReader = await columnsCmd.ExecuteReaderAsync())
                    {
                        while (await columnReader.ReadAsync())
                            columns[columnReader.GetString(0)] = columnReader.GetString(1) == "YES";
                    }
                    if (columns.Count == 0)
                    {
                        missingTables.Add($"{schema}.{table}");
                        continue;
                    }
                    foreach (var property in entity.GetProperties())
                    {
                        var column = property.GetColumnName(store);
                        if (column is null) continue;
                        if (!columns.TryGetValue(column, out var nullableInSql))
                        {
                            issues.Add($"{entity.ClrType.Name}.{property.Name} -> {schema}.{table}.{column}");
                        }
                        else if (nullableInSql && !property.IsNullable)
                        {
                            nullability.Add($"{entity.ClrType.Name}.{property.Name} -> {schema}.{table}.{column}: SQL cho NULL, EF không cho NULL");
                        }
                    }
                }
                return Json(new { database, server, bangKhongKhop = missingTables,
                    cotKhongKhop = issues, nullableKhongKhop = nullability });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.GetBaseException().Message });
        }
        finally
        {
            if (conn.State == ConnectionState.Open) await conn.CloseAsync();
        }
    }
}
