namespace RentalCamera.Api.Contracts;
public static class ReturnTimeCorrectionEndpoints
{
    public static void MapReturnTimeCorrectionEndpoints(this IEndpointRouteBuilder app) =>
        app.MapPut("/api/chi-tiet-hop-dong/{id}/thoi-gian-nhan", () => Results.Conflict(new {
            code="USE_ATOMIC_RECEIPT_CORRECTION", loi="Sửa thời điểm thực nhận chung tại /api/hop-dong/{id}/nhan-lai/thoi-gian." })).RequireAuthorization("Staff");
}
public sealed record ReturnTimeCorrection(DateTime NgayNhanThucTe, string LyDo);
