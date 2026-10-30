using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Email;
using RentalCamera.Api.Infrastructure;

internal static class ContractSmtpDemoChecks
{
    public static async Task RunAsync()
    {
        var count = 0;
        void Check(bool condition, string name)
        {
            if (!condition) throw new Exception(name);
            count++;
        }
        IConfiguration Config(Dictionary<string, string?> values) =>
            new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        void Rejected(string key, string? value, string name)
        {
            var values = Settings(true);
            values[key] = value;
            var rejected = false;
            try { _ = new Schema33TrialGuard(Config(values), new OfflineEnvironment()); }
            catch (InvalidOperationException) { rejected = true; }
            Check(rejected, name);
        }
        ServiceProvider Providers(IConfiguration config, Schema33TrialGuard guard)
        {
            var services = new ServiceCollection();
            services.AddLogging();
            services.Configure<EmailOptions>(config.GetSection("Email"));
            services.AddSingleton<FakeTrialSender>();
            services.AddSingleton<IContractOtpEmailSender>(sp => sp.GetRequiredService<FakeTrialSender>());
            services.AddSingleton<IAuthEmailSender>(sp => sp.GetRequiredService<FakeTrialSender>());
            ContractSigningOtpRegistration.Register(services, guard);
            return services.BuildServiceProvider();
        }

        var fakeConfig = Config(Settings(false));
        var fakeGuard = new Schema33TrialGuard(fakeConfig, new OfflineEnvironment());
        using (var providers = Providers(fakeConfig, fakeGuard))
        {
            Check(!fakeGuard.ContractSmtpDemoEnabled, "Default profile stays fake");
            Check(ReferenceEquals(providers.GetRequiredKeyedService<IContractOtpEmailSender>(ContractSigningOtpRegistration.ServiceKey),
                providers.GetRequiredService<FakeTrialSender>()), "Default contract sender is the fake mailbox");
            Check(providers.GetService<SmtpContractOtpEmailSender>() is null, "Default profile does not construct SMTP");
        }

        var config = Config(Settings(true));
        var guard = new Schema33TrialGuard(config, new OfflineEnvironment());
        using (var providers = Providers(config, guard))
        {
            Check(guard.ContractSmtpDemoEnabled, "Approved SMTP profile is accepted without opening SQL");
            Check(providers.GetRequiredKeyedService<IContractOtpEmailSender>(ContractSigningOtpRegistration.ServiceKey)
                is RestrictedContractOtpEmailSender { IsConfigured: true }, "Signing key resolves restricted SMTP");
            Check(providers.GetRequiredService<IContractOtpEmailSender>() is FakeTrialSender, "Unkeyed/default sender stays fake");
            Check(providers.GetRequiredService<IAuthEmailSender>() is FakeTrialSender, "Verification/password-reset sender stays fake");
        }

        Rejected("ContractOtpEmail:SmtpApproved", "false", "Unapproved SMTP is blocked");
        Rejected("ContractOtpEmail:Mode", "Unknown", "Unknown mode is blocked");
        Rejected("ContractOtpEmail:Mode", "Fake", "SMTP cannot leak into fake mode");
        Rejected("ContractOtpEmail:AllowedRecipient", "", "Recipient approval is required");
        Rejected("ContractOtpEmail:AllowedRecipient", "Name <allowed@example.invalid>", "Display-name allowlist is rejected");
        Rejected("Email:Enabled", "false", "SMTP enabled flag is required");
        Rejected("Email:Host", "", "SMTP host is required");
        Rejected("Email:Port", "465", "Implicit TLS port is rejected");
        Rejected("Email:UseSsl", "false", "STARTTLS cannot be disabled");
        Rejected("Email:Password", "", "SMTP password is required");
        Rejected("Email:FromAddress", "different@example.invalid", "Sender identity cannot differ from login");
        Rejected("ElectronicSignature:Pepper", "", "Pepper is required");
        Rejected("Schema33Trial:ProviderMode", "Real", "Global providers cannot become real");
        Rejected("Schema33Trial:PackageApproved", "false", "DB package approval is still required");
        Rejected("Schema33Trial:ExpectedDataSource", "other-server", "Data-source binding cannot change");
        Rejected("ConnectionStrings:RentalCamera", "Server=offline-sql;Database=OtherDb;User ID=trial_runtime;Password=offline-only", "Other DB is rejected");
        Rejected("ConnectionStrings:RentalCamera", "Server=offline-sql;Database=RentalCameraDb30_Test;User ID=sa;Password=offline-only", "Admin SQL login is rejected");
        Rejected("ConnectionStrings:RentalCamera", "Server=offline-sql;Database=RentalCameraDb30_Test;Integrated Security=true", "Integrated SQL authentication is rejected");
        Rejected("Rental:BackgroundJobsEnabled", "true", "Jobs remain disabled");
        Rejected("Notifications:PushEnabled", "true", "Push remains disabled");
        Rejected("Chatbot:Enabled", "true", "Chatbot remains disabled");
        Rejected("ElectronicSignature:ReturnOtpInResponse", "true", "OTP response fallback remains blocked");
        Rejected("PasswordReset:ReturnTokenInResponse", "true", "Auth token response fallback remains blocked");
        Rejected("Vnpay:FakeTrial", "false", "Payment must remain fake");
        Rejected("Vnpay:PaymentUrl", "https://example.invalid/payment", "External payment URL is rejected");
        try
        {
            _ = new Schema33TrialGuard(config, new OfflineEnvironment { EnvironmentName = "Production" });
            throw new Exception("Production environment was incorrectly accepted");
        }
        catch (InvalidOperationException) { count++; }

        var capture = new CaptureSender();
        var sender = new RestrictedContractOtpEmailSender(capture, guard.AllowedContractOtpRecipient!);
        var expiresAt = new DateTime(2030, 1, 1, 0, 5, 0, DateTimeKind.Utc);
        await sender.SendAsync("ALLOWED@example.invalid", "Offline customer", "OFFLINE_CONTRACT", "offline-placeholder", expiresAt, CancellationToken.None);
        Check(capture.Calls == 1 && capture.Recipient == "ALLOWED@example.invalid", "Original server recipient is forwarded without replacement");
        foreach (var recipient in new[] { "other@example.invalid", "allowed@example.invalid.attacker.invalid", "Name <allowed@example.invalid>", "" })
        {
            var blocked = false;
            try { await sender.SendAsync(recipient, "Offline", "OFFLINE_CONTRACT", "offline-placeholder", expiresAt, CancellationToken.None); }
            catch (InvalidOperationException) { blocked = true; }
            Check(blocked && capture.Calls == 1, "Unapproved recipient never reaches transport");
        }
        using (var cancelled = new CancellationTokenSource())
        {
            cancelled.Cancel();
            try
            {
                await sender.SendAsync("allowed@example.invalid", "Offline", "OFFLINE_CONTRACT", "offline-placeholder", expiresAt, cancelled.Token);
                throw new Exception("Cancelled email was accepted");
            }
            catch (OperationCanceledException) { Check(capture.Calls == 1, "Cancellation never reaches transport"); }
        }
        capture.Fail = true;
        try
        {
            await sender.SendAsync("allowed@example.invalid", "Offline", "OFFLINE_CONTRACT", "offline-placeholder", expiresAt, CancellationToken.None);
            throw new Exception("Transport failure was swallowed");
        }
        catch (OfflineTransportException) { Check(capture.Calls == 2, "Transport failure propagates without retry"); }

        var signature = new ContractSignatureService(config);
        var hash = signature.HashOtp("offline-placeholder");
        Check(new ContractSignatureService(config).VerifyOtp("offline-placeholder", hash.Hash, hash.Salt), "Same Pepper survives service reconstruction");
        var appendixCapture = new CaptureSender();
        var appendixSender = new RestrictedContractOtpEmailSender(appendixCapture, guard.AllowedContractOtpRecipient!);
        await appendixSender.SendAsync("ALLOWED@example.invalid", "Offline customer", "phụ lục OFFLINE_APPENDIX",
            "offline-placeholder", expiresAt, CancellationToken.None);
        Check(appendixCapture.Calls == 1 && appendixCapture.Recipient == "ALLOWED@example.invalid" &&
            appendixCapture.DocumentId == "phụ lục OFFLINE_APPENDIX", "Appendix keeps the server recipient and document identity");
        try
        {
            await appendixSender.SendAsync("other@example.invalid", "Offline", "phụ lục OFFLINE_APPENDIX",
                "offline-placeholder", expiresAt, CancellationToken.None);
            throw new Exception("Unapproved appendix recipient was accepted");
        }
        catch (InvalidOperationException) { Check(appendixCapture.Calls == 1, "Appendix recipient outside allowlist never reaches transport"); }
        appendixCapture.Fail = true;
        try
        {
            await appendixSender.SendAsync("allowed@example.invalid", "Offline", "phụ lục OFFLINE_APPENDIX",
                "offline-placeholder", expiresAt, CancellationToken.None);
            throw new Exception("Appendix transport failure was swallowed");
        }
        catch (OfflineTransportException) { Check(appendixCapture.Calls == 2, "Appendix transport failure propagates without retry"); }
        await AppendixOtpProviderChecks.RunAsync(Check);
        Console.WriteLine($"PASS {count} contract/appendix SMTP guard/provider checks; no SQL, network HTTP or SMTP calls.");
    }

    private static Dictionary<string, string?> Settings(bool smtp) => new()
    {
        ["Schema33Trial:Enabled"] = "true", ["Schema33Trial:PackageApproved"] = "true",
        ["Schema33Trial:ExpectedDataSource"] = "offline-sql", ["Schema33Trial:ProviderMode"] = "Fake",
        ["ConnectionStrings:RentalCamera"] = "Server=offline-sql;Database=RentalCameraDb30_Test;User ID=trial_runtime;Password=offline-only",
        ["Vnpay:FakeTrial"] = "true", ["Vnpay:PaymentUrl"] = "http://127.0.0.1/fake-payment",
        ["Vnpay:ReturnUrl"] = "http://127.0.0.1/return", ["Vnpay:IpnUrl"] = "http://127.0.0.1/ipn",
        ["Vnpay:QueryDrUrl"] = "http://127.0.0.1/query", ["ContractOtpEmail:Mode"] = smtp ? "SmtpDemo" : "Fake",
        ["ContractOtpEmail:SmtpApproved"] = smtp ? "true" : "false",
        ["ContractOtpEmail:AllowedRecipient"] = smtp ? "allowed@example.invalid" : "",
        ["Email:Enabled"] = smtp ? "true" : "false", ["Email:Host"] = "smtp.example.invalid",
        ["Email:Port"] = "587", ["Email:UseSsl"] = "true", ["Email:Username"] = "sender@example.invalid",
        ["Email:FromAddress"] = "sender@example.invalid", ["Email:Password"] = "offline-placeholder",
        ["ElectronicSignature:Pepper"] = "offline-placeholder-not-a-real-secret"
    };

    private sealed class OfflineEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Schema33Trial";
        public string ApplicationName { get; set; } = "OfflineSmtpChecks";
        public string ContentRootPath { get; set; } = "/tmp";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private sealed class CaptureSender : IContractOtpEmailSender
    {
        public bool IsConfigured => true;
        public int Calls { get; private set; }
        public string? Recipient { get; private set; }
        public string? DocumentId { get; private set; }
        public bool Fail { get; set; }
        public Task SendAsync(string recipientEmail, string recipientName, string contractId,
            string otp, DateTime expiresAt, CancellationToken cancellationToken)
        {
            Calls++;
            Recipient = recipientEmail;
            DocumentId = contractId;
            return Fail ? Task.FromException(new OfflineTransportException()) : Task.CompletedTask;
        }
    }
    private sealed class OfflineTransportException : Exception { }
}
