using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace RentalCamera.Api.Infrastructure;

public static class ConcurrencyResponse
{
    public static bool IsRetryable(Exception error) =>
        (error as SqlException ?? (error as DbUpdateException)?.InnerException as SqlException)?.Number
            is 1205 or 1222 or 51001 or 2601 or 2627;

    public static void UseConcurrencyResponse(this WebApplication app) => app.Use(async (context,next)=>{
        try { await next(context); }
        catch(Exception error) when(IsRetryable(error)&&!context.Response.HasStarted) {
            context.Response.Clear();
            if(context.Request.Path=="/api/thanh-toan/vnpay/ipn") {
                context.Response.StatusCode=200;
                await context.Response.WriteAsJsonAsync(new{RspCode="99",Message="Concurrent update; retry notification"});
            } else {
                context.Response.StatusCode=409;
                await context.Response.WriteAsJsonAsync(new{errorCode="CONCURRENT_CHANGE",loi="Dữ liệu vừa thay đổi hoặc đang được xử lý. Hãy tải lại để đối soát trước khi thử lại."});
            }
        }
    });
}
