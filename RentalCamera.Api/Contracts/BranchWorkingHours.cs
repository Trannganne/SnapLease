using RentalCamera.Api.Data;
namespace RentalCamera.Api.Contracts;

public sealed class BranchWorkingHours(IConfiguration configuration)
{
    private (TimeOnly Open, TimeOnly Close) Hours()
    {
        var open = TimeOnly.ParseExact(configuration["Rental:OpeningTime"] ?? "08:00", "HH:mm", System.Globalization.CultureInfo.InvariantCulture);
        var close = TimeOnly.ParseExact(configuration["Rental:ClosingTime"] ?? "20:00", "HH:mm", System.Globalization.CultureInfo.InvariantCulture);
        if (close <= open) throw new InvalidOperationException("Giờ phục vụ không hợp lệ.");
        return (open, close);
    }
    public static DateTime? AddHours(IEnumerable<(DateTime Start, DateTime End)> intervals, DateTime from, TimeSpan remaining)
    {
        foreach (var (opening, closing) in intervals.OrderBy(x => x.Start))
        {
            var start = opening > from ? opening : from;
            if (start >= closing) continue;
            if (closing - start >= remaining) return start.Add(remaining);
            remaining -= closing - start;
        }
        return null;
    }
    private IEnumerable<(DateTime Start, DateTime End)> Intervals(DateTime from)
    {
        var first = DateOnly.FromDateTime(from.AddHours(7)); var (open, close) = Hours();
        for (var i = 0; i <= 370; i++)
        {
            var day = first.AddDays(i);
            yield return (RentalPolicy.Utc(day.ToDateTime(open)), RentalPolicy.Utc(day.ToDateTime(close)));
        }
    }
    public Task<DateTime?> AddWorkingHoursUtcAsync(string store, DateTime fromUtc, int hours, CancellationToken ct) =>
        Task.FromResult(AddHours(Intervals(fromUtc), fromUtc, TimeSpan.FromHours(hours)));
    public Task<bool> IsOpenAsync(string store, DateTime utc, CancellationToken ct) =>
        Task.FromResult(Intervals(utc).Any(x => x.Start <= utc && utc < x.End));
    public Task<DateTime?> NextOpeningAsync(string store, DateTime utc, CancellationToken ct) =>
        Task.FromResult<DateTime?>(Intervals(utc).Where(x => x.End > utc).Select(x => x.Start > utc ? x.Start : utc).FirstOrDefault());
    public static void MapWorkingHoursEndpoints(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/cua-hang/{id}/lich-lam-viec", (string id, BranchWorkingHours hours) => {
            var (open, close) = hours.Hours();
            return Results.Ok(new { muiGio = "Asia/Ho_Chi_Minh", cauHinhCoDinh = true,
                tuan = Enumerable.Range(0, 7).Select(day => new { maCuaHang = id, ngayTrongTuan = day,
                    gioMoCua = open, gioDongCua = close }), ngoaiLe = Array.Empty<object>() });
        });
        app.MapPut("/api/cua-hang/{id}/lich-lam-viec/{ngay}", () => Results.Json(new {
            code = "WORKING_HOURS_CONFIG_ONLY", loi = "Giờ phục vụ được cấu hình tại backend." }, statusCode: 410)).RequireAuthorization("Admin");
    }
}
