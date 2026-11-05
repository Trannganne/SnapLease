using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;

namespace RentalCamera.Api.Notifications;

public static class FirebaseRegistration
{
    public const string AppName = "snaplease-notifications";

    public static FirebaseApp CreateApp(IServiceProvider services)
    {
        var configuration = services.GetRequiredService<IConfiguration>();
        var environment = services.GetRequiredService<IHostEnvironment>();
        var projectId = configuration["Firebase:ProjectId"]?.Trim();
        var configuredPath = configuration["Firebase:CredentialsPath"]?.Trim();

        if (string.IsNullOrWhiteSpace(projectId) || string.IsNullOrWhiteSpace(configuredPath))
            throw new InvalidOperationException("Firebase Admin chưa có ProjectId hoặc CredentialsPath.");

        var credentialsPath = Path.IsPathRooted(configuredPath)
            ? configuredPath
            : Path.GetFullPath(configuredPath, environment.ContentRootPath);
        if (!File.Exists(credentialsPath))
            throw new InvalidOperationException("Không tìm thấy file Firebase Admin credentials đã cấu hình.");

        return FirebaseApp.Create(new AppOptions
        {
            ProjectId = projectId,
            Credential = CredentialFactory.FromFile<ServiceAccountCredential>(credentialsPath).ToGoogleCredential()
        }, AppName);
    }
}
