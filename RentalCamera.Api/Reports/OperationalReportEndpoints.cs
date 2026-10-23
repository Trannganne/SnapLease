using System.Globalization;
using System.Security.Claims;
using System.Text;
using System.Xml;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Reports;

public static class OperationalReportEndpoints
{
    public static void MapOperationalReportEndpoints(this IEndpointRouteBuilder app)
    {
        var reports = app.MapGroup("/api/bao-cao").RequireAuthorization("Staff");

        reports.MapGet("/hieu-suat-dong-may", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveScope(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter.Result is not null) return filter.Result;
            var table = await BuildModelPerformance(filter.Value!, db, ct);
            return Results.Ok(new { filter.Value!.StoreId, filter.Value.From, filter.Value.To,
                duLieu = table.Objects });
        }).WithName("Báo cáo hiệu suất dòng máy");

        reports.MapGet("/ty-le-su-dung-thiet-bi", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveScope(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter.Result is not null) return filter.Result;
            var table = await BuildUtilization(filter.Value!, db, ct);
            return Results.Ok(new { filter.Value!.StoreId, filter.Value.From, filter.Value.To,
                duLieu = table.Objects });
        }).WithName("Báo cáo tỷ lệ sử dụng thiết bị");

        reports.MapGet("/tien-coc-va-phieu-phat", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveScope(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter.Result is not null) return filter.Result;
            var table = await BuildDepositsAndPenalties(filter.Value!, db, ct);
            return Results.Ok(new { filter.Value!.StoreId, filter.Value.From, filter.Value.To,
                duLieu = table.Objects });
        }).WithName("Báo cáo tiền cọc và phiếu phạt");

        reports.MapGet("/xuat", async (
            string loai, string dinhDang, string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveScope(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter.Result is not null) return filter.Result;
            var type = loai.Trim().ToUpperInvariant();
            ReportTable? table = type switch
            {
                "HIEU_SUAT_DONG_MAY" => await BuildModelPerformance(filter.Value!, db, ct),
                "TY_LE_SU_DUNG" => await BuildUtilization(filter.Value!, db, ct),
                "TIEN_COC_PHAT" => await BuildDepositsAndPenalties(filter.Value!, db, ct),
                _ => null
            };
            if (table is null)
                return Results.BadRequest(new { loi = "Loại báo cáo không hợp lệ." });
            var format = dinhDang.Trim().ToUpperInvariant();
            var stamp = DateTime.UtcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
            return format switch
            {
                "EXCEL" or "XLS" => Results.File(ReportExportWriter.ToExcelXml(table),
                    "application/vnd.ms-excel", $"{type}_{stamp}.xls"),
                "PDF" => Results.File(ReportExportWriter.ToPdf(table), "application/pdf", $"{type}_{stamp}.pdf"),
                _ => Results.BadRequest(new { loi = "Định dạng phải là EXCEL hoặc PDF." })
            };
        }).WithName("Xuất báo cáo Excel PDF");
    }

    private static async Task<(ReportScope? Value, IResult? Result)> ResolveScope(
        string? requestedStore, DateTime? from, DateTime? to, ClaimsPrincipal principal,
        RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return (null, Results.Forbid());
        if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(requestedStore) && requestedStore != scope.StoreId)
            return (null, Results.Forbid());
        var start = from?.Date ?? DateTime.Today.AddMonths(-1);
        var end = (to?.Date ?? DateTime.Today).AddDays(1);
        if (end <= start) return (null, Results.BadRequest(new { loi = "Khoảng ngày không hợp lệ." }));
        return (new ReportScope(scope.IsAdmin ? requestedStore?.Trim() : scope.StoreId, start, end), null);
    }

    private static async Task<ReportTable> BuildModelPerformance(
        ReportScope filter, RentalCameraContext db, CancellationToken ct)
    {
        var query = from detail in db.ChiTietHopDong.AsNoTracking()
                    join contract in db.HopDong.AsNoTracking() on detail.MaHopDong equals contract.MaHopDong
                    join device in db.ThietBi.AsNoTracking() on detail.MaThietBi equals device.MaThietBi
                    join model in db.DongMay.AsNoTracking() on device.MaDongMay equals model.MaDongMay
                    where contract.NgayTaoHopDong >= filter.From && contract.NgayTaoHopDong < filter.To &&
                        contract.TrangThai != "DA_HUY" &&
                        (filter.StoreId == null || contract.MaCuaHang == filter.StoreId)
                    select new { contract.MaHopDong, contract.MaCuaHang, model.MaDongMay,
                        model.TenDongMay, detail.MaThietBi, detail.DonGia };
        var rows = await query.ToListAsync(ct);
        var data = rows.GroupBy(x => new { x.MaCuaHang, x.MaDongMay, x.TenDongMay })
            .Select(x => new object[] { x.Key.MaCuaHang, x.Key.MaDongMay, x.Key.TenDongMay,
                x.Select(y => y.MaHopDong).Distinct().Count(), x.Select(y => y.MaThietBi).Distinct().Count(),
                x.Sum(y => y.DonGia) })
            .OrderByDescending(x => Convert.ToInt32(x[3])).ThenBy(x => x[1]?.ToString()).ToList();
        return ReportTable.Create("Hiệu suất dòng máy",
            ["Mã cửa hàng", "Mã dòng máy", "Tên dòng máy", "Số lượt thuê", "Số serial", "Doanh thu phân bổ"], data);
    }

    private static async Task<ReportTable> BuildUtilization(
        ReportScope filter, RentalCameraContext db, CancellationToken ct)
    {
        var devices = await db.ThietBi.AsNoTracking()
            .Where(x => filter.StoreId == null || x.MaCuaHang == filter.StoreId)
            .Join(db.DongMay.AsNoTracking(), x => x.MaDongMay, x => x.MaDongMay,
                (device, model) => new { device.MaThietBi, device.MaCuaHang, model.MaDongMay, model.TenDongMay })
            .ToListAsync(ct);
        var deviceIds = devices.Select(x => x.MaThietBi).ToList();
        var rentals = await (from detail in db.ChiTietHopDong.AsNoTracking()
                             join contract in db.HopDong.AsNoTracking() on detail.MaHopDong equals contract.MaHopDong
                             where deviceIds.Contains(detail.MaThietBi) && contract.TrangThai != "DA_HUY" &&
                                contract.ThoiGianBanGiao < filter.To && contract.ThoiGianTraDuKien >= filter.From
                             select new { detail.MaThietBi,
                                 Start = detail.NgayGiaoThucTe ?? contract.ThoiGianBanGiao,
                                 End = detail.NgayNhanThucTe ?? contract.ThoiGianTraDuKien }).ToListAsync(ct);
        var periodHours = Math.Max((filter.To - filter.From).TotalHours, 1);
        var data = devices.GroupBy(x => new { x.MaCuaHang, x.MaDongMay, x.TenDongMay })
            .Select(group =>
            {
                var ids = group.Select(x => x.MaThietBi).ToHashSet();
                var used = rentals.Where(x => ids.Contains(x.MaThietBi)).Sum(x =>
                    Math.Max(0, (Min(x.End, filter.To) - Max(x.Start, filter.From)).TotalHours));
                var capacity = group.Count() * periodHours;
                return new object[] { group.Key.MaCuaHang, group.Key.MaDongMay, group.Key.TenDongMay,
                    group.Count(), decimal.Round((decimal)used, 2), decimal.Round((decimal)capacity, 2),
                    capacity <= 0 ? 0 : decimal.Round((decimal)(used / capacity * 100), 2) };
            }).OrderByDescending(x => Convert.ToDecimal(x[6])).ToList();
        return ReportTable.Create("Tỷ lệ sử dụng thiết bị",
            ["Mã cửa hàng", "Mã dòng máy", "Tên dòng máy", "Số thiết bị", "Giờ sử dụng", "Giờ khả dụng", "Tỷ lệ (%)"], data);
    }

    private static async Task<ReportTable> BuildDepositsAndPenalties(
        ReportScope filter, RentalCameraContext db, CancellationToken ct)
    {
        var contracts = db.HopDong.AsNoTracking().Where(x =>
            filter.StoreId == null || x.MaCuaHang == filter.StoreId);
        var payments = await db.ThanhToan.AsNoTracking().Where(x =>
                contracts.Any(h => h.MaHopDong == x.MaHopDong) &&
                x.ThoiGian >= filter.From && x.ThoiGian < filter.To &&
                ((x.LoaiThanhToan == "TIEN_COC" && x.TrangThai == "THANH_CONG") ||
                 (x.LoaiThanhToan == "HOAN_COC" && x.TrangThai == "DA_HOAN")))
            .Join(contracts, x => x.MaHopDong, x => x.MaHopDong,
                (payment, contract) => new { payment, contract.MaCuaHang }).ToListAsync(ct);
        var penalties = await (from penalty in db.PhieuPhat.AsNoTracking()
                               join detail in db.ChiTietHopDong.AsNoTracking() on penalty.MaChiTietHopDong equals detail.MaChiTietHopDong
                               join contract in contracts on detail.MaHopDong equals contract.MaHopDong
                               where penalty.NgayLap >= filter.From && penalty.NgayLap < filter.To &&
                                     penalty.TrangThai != "HUY"
                               select new { contract.MaCuaHang, penalty.SoTien }).ToListAsync(ct);
        var stores = payments.Select(x => x.MaCuaHang).Concat(penalties.Select(x => x.MaCuaHang)).Distinct();
        var data = stores.Select(store => new object[]
        {
            store,
            payments.Where(x => x.MaCuaHang == store && x.payment.LoaiThanhToan == "TIEN_COC").Sum(x => x.payment.SoTien),
            payments.Where(x => x.MaCuaHang == store && x.payment.LoaiThanhToan == "HOAN_COC").Sum(x => x.payment.SoTien),
            penalties.Where(x => x.MaCuaHang == store).Sum(x => x.SoTien),
            penalties.Count(x => x.MaCuaHang == store)
        }).OrderBy(x => x[0]?.ToString()).ToList();
        return ReportTable.Create("Tiền cọc và phiếu phạt",
            ["Mã cửa hàng", "Tiền cọc đã thu", "Tiền cọc đã hoàn", "Tổng tiền phạt", "Số phiếu phạt"], data);
    }

    private static DateTime Min(DateTime left, DateTime right) => left < right ? left : right;
    private static DateTime Max(DateTime left, DateTime right) => left > right ? left : right;
    private sealed record ReportScope(string? StoreId, DateTime From, DateTime To);
}

internal sealed record ReportTable(string Title, string[] Headers, List<object[]> Rows, List<Dictionary<string, object?>> Objects)
{
    public static ReportTable Create(string title, string[] headers, List<object[]> rows) =>
        new(title, headers, rows, rows.Select(row => headers.Select((header, index) => new { header, index })
            .ToDictionary(x => x.header, x => (object?)row[x.index])).ToList());
}

internal static class ReportExportWriter
{
    public static byte[] ToExcelXml(ReportTable table)
    {
        const string spreadsheetNamespace = "urn:schemas-microsoft-com:office:spreadsheet";
        var settings = new XmlWriterSettings { Encoding = new UTF8Encoding(false), Indent = true };
        using var stream = new MemoryStream();
        using (var writer = XmlWriter.Create(stream, settings))
        {
            writer.WriteStartDocument();
            writer.WriteProcessingInstruction("mso-application", "progid=\"Excel.Sheet\"");
            writer.WriteStartElement("Workbook", spreadsheetNamespace);
            writer.WriteAttributeString("xmlns", "ss", null, spreadsheetNamespace);
            writer.WriteStartElement("Worksheet", spreadsheetNamespace); writer.WriteAttributeString("ss", "Name", null, "Bao cao");
            writer.WriteStartElement("Table", spreadsheetNamespace);
            WriteExcelRow(writer, table.Headers.Cast<object?>(), spreadsheetNamespace);
            foreach (var row in table.Rows) WriteExcelRow(writer, row, spreadsheetNamespace);
            writer.WriteEndElement(); writer.WriteEndElement(); writer.WriteEndElement();
            writer.WriteEndDocument();
        }
        return stream.ToArray();
    }

    private static void WriteExcelRow(XmlWriter writer, IEnumerable<object?> values, string spreadsheetNamespace)
    {
        writer.WriteStartElement("Row", spreadsheetNamespace);
        foreach (var value in values)
        {
            writer.WriteStartElement("Cell", spreadsheetNamespace); writer.WriteStartElement("Data", spreadsheetNamespace);
            var numeric = value is byte or short or int or long or float or double or decimal;
            writer.WriteAttributeString("ss", "Type", null, numeric ? "Number" : "String");
            writer.WriteString(Convert.ToString(value, CultureInfo.InvariantCulture) ?? "");
            writer.WriteEndElement(); writer.WriteEndElement();
        }
        writer.WriteEndElement();
    }

    public static byte[] ToPdf(ReportTable table)
    {
        var lines = new List<string> { table.Title, string.Join(" | ", table.Headers) };
        lines.AddRange(table.Rows.Select(row => string.Join(" | ", row.Select(x => Convert.ToString(x, CultureInfo.InvariantCulture)))));
        var content = new StringBuilder("BT /F1 9 Tf 40 800 Td 12 TL ");
        foreach (var line in lines.Take(55))
            content.Append('(').Append(ToPdfAscii(line)).Append(") Tj T* ");
        content.Append("ET");
        var body = content.ToString();
        var objects = new[]
        {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
            $"<< /Length {Encoding.ASCII.GetByteCount(body)} >>\nstream\n{body}\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
        };
        using var stream = new MemoryStream();
        void Write(string value) { var bytes = Encoding.ASCII.GetBytes(value); stream.Write(bytes); }
        Write("%PDF-1.4\n");
        var offsets = new List<long> { 0 };
        for (var i = 0; i < objects.Length; i++)
        {
            offsets.Add(stream.Position); Write($"{i + 1} 0 obj\n{objects[i]}\nendobj\n");
        }
        var xref = stream.Position;
        Write($"xref\n0 {objects.Length + 1}\n0000000000 65535 f \n");
        foreach (var offset in offsets.Skip(1)) Write($"{offset:0000000000} 00000 n \n");
        Write($"trailer << /Size {objects.Length + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF");
        return stream.ToArray();
    }

    private static string ToPdfAscii(string value)
    {
        var normalized = value.Normalize(NormalizationForm.FormD);
        var ascii = new string(normalized.Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            .Select(c => c <= 127 ? c : '?').ToArray());
        return ascii.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");
    }
}
