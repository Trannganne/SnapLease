using Microsoft.Extensions.Options;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Chatbot;

public static class ChatEndpoints
{
    public static void AddChatbot(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<ChatbotOptions>(configuration.GetSection("Chatbot"));
        services.AddSingleton(provider => ChatKnowledge.Load(provider.GetRequiredService<IHostEnvironment>().ContentRootPath));
        services.AddScoped<IChatCatalog, EfChatCatalog>();
        services.AddHttpClient<IChatProvider, GroqChatProvider>(client => client.Timeout = Timeout.InfiniteTimeSpan)
            .ConfigurePrimaryHttpMessageHandler(() => configuration["Schema33Trial:ProviderMode"] == "Fake"
                ? new DenyExternalHttpHandler()
                : new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<ChatService>();
    }
    public static void MapChatbotEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tro-ly").RequireAuthorization("Customer");
        group.MapGet("/trang-thai", (ChatService service) => Results.Ok(new {
            enabled = service.UnavailableReason is null, reason = service.UnavailableReason,
            model = ChatbotOptions.Model
        }));
        group.MapPost("/tin-nhan", async (ChatRequest request, ChatService service, CancellationToken ct) => {
            try { return Results.Ok(await service.ReplyAsync(request, ct)); }
            catch (ChatFailure failure) { return Results.Json(new { code = failure.Code, loi = failure.Message }, statusCode: failure.Status); }
        }).RequireRateLimiting("chatbot").WithMetadata(new Microsoft.AspNetCore.Mvc.RequestSizeLimitAttribute(16384));
    }
}
