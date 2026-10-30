using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Email;
using RentalCamera.Api.Rental;

internal static class AppendixOtpProviderChecks
{
    // Exercise the mapped production endpoint without starting a server. Both
    // probes are unavailable, so neither wiring can reach SQL or generate OTPs.
    public static async Task RunAsync(Action<bool, string> check)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            Args = [], EnvironmentName = "OfflineSmtpChecks",
            ContentRootPath = AppContext.BaseDirectory
        });
        builder.Configuration.Sources.Clear();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ElectronicSignature:Pepper"] = "offline-placeholder-not-a-real-secret"
        });
        builder.Logging.ClearProviders();
        builder.Services.AddDbContext<RentalCameraContext>(options => options.UseSqlServer(
            "Server=offline.invalid;Database=OfflineOnly;User ID=offline;Password=offline-only"));
        builder.Services.AddScoped<AvailabilityService>();
        builder.Services.AddSingleton<BranchWorkingHours>();
        builder.Services.AddSingleton<ContractSignatureService>();
        builder.Services.AddSingleton<ContractPdfService>();
        var defaultSender = new UnavailableSender();
        var signingSender = new UnavailableSender();
        builder.Services.AddSingleton<IContractOtpEmailSender>(defaultSender);
        builder.Services.AddKeyedSingleton<IContractOtpEmailSender>(
            ContractSigningOtpRegistration.ServiceKey, (_, _) => signingSender);

        await using var app = builder.Build();
        app.MapRenewalEndpoints();
        var endpoint = ((IEndpointRouteBuilder)app).DataSources
            .SelectMany(source => source.Endpoints).OfType<RouteEndpoint>()
            .Single(endpoint => endpoint.RoutePattern.RawText == "/api/gia-han/{id}/yeu-cau-ky");
        using var scope = app.Services.CreateScope();
        var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        context.Request.Method = "POST";
        context.Request.Path = "/api/gia-han/OFFLINE_APPENDIX/yeu-cau-ky";
        context.Request.RouteValues["id"] = "OFFLINE_APPENDIX";
        await using var response = new MemoryStream();
        context.Response.Body = response;
        await endpoint.RequestDelegate!(context);

        check(context.Response.StatusCode == 503, "Unavailable appendix signing provider returns 503");
        check(signingSender.ConfigurationReads == 1 && defaultSender.ConfigurationReads == 0,
            "Appendix endpoint resolves the signing key, never the default fake provider");
        check(signingSender.Sends == 0 && defaultSender.Sends == 0,
            "Unavailable appendix provider does not generate a transport call or fall back");
    }

    private sealed class UnavailableSender : IContractOtpEmailSender
    {
        public int ConfigurationReads { get; private set; }
        public int Sends { get; private set; }
        public bool IsConfigured { get { ConfigurationReads++; return false; } }
        public Task SendAsync(string recipientEmail, string recipientName, string contractId,
            string otp, DateTime expiresAt, CancellationToken cancellationToken)
        {
            Sends++;
            throw new InvalidOperationException("Unavailable offline provider must not send.");
        }
    }
}
