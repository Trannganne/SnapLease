using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.OpenApi.Models;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Catalog;
using RentalCamera.Api.Chatbot;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Email;
using RentalCamera.Api.Equipment;
using RentalCamera.Api.Handover;
using RentalCamera.Api.Identity;
using RentalCamera.Api.Media;
using RentalCamera.Api.Notifications;
using RentalCamera.Api.Payments;
using RentalCamera.Api.Penalties;
using RentalCamera.Api.Rental;
using RentalCamera.Api.Reports;
using RentalCamera.Api.Reviews;
using RentalCamera.Api.Settlement;
using System.Threading.RateLimiting;
using RentalCamera.Api.Infrastructure;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Fail before service creation, network access or any database open.
var trialGuard = new Schema33TrialGuard(builder.Configuration, builder.Environment);
builder.Services.AddSingleton(trialGuard);
var connectionString = builder.Configuration.GetConnectionString("RentalCamera")!;
builder.Services.AddDbContext<RentalCameraContext>(options => options.UseSqlServer(connectionString).AddInterceptors(trialGuard));
builder.Services.AddCors(options => options.AddPolicy("Frontend", policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    if (origins.Length > 0)
        policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));
var keyDirectory = Path.Combine(builder.Environment.ContentRootPath, ".keys");
var dataProtection = builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(keyDirectory))
    .SetApplicationName("RentalCamera.Api");
if (OperatingSystem.IsWindows()) dataProtection.ProtectKeysWithDpapi();
builder.Services.AddScoped<IPasswordHasher<TaiKhoan>, PasswordHasher<TaiKhoan>>();
builder.Services.Configure<PasswordHasherOptions>(options => options.IterationCount = 100_000);
builder.Services.AddSingleton<TokenIssuer>();
builder.Services.AddSingleton<PasswordResetTokenService>();
builder.Services.AddSingleton<AuthLinkService>();
builder.Services.AddSingleton<ContractSignatureService>();
builder.Services.AddSingleton<ContractPdfService>();
builder.Services.AddScoped<BranchWorkingHours>();
builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection(EmailOptions.SectionName));
builder.Services.AddSingleton<FakeTrialSender>();
builder.Services.AddSingleton<IContractOtpEmailSender>(sp => sp.GetRequiredService<FakeTrialSender>());
builder.Services.AddSingleton<IAuthEmailSender>(sp => sp.GetRequiredService<FakeTrialSender>());
builder.Services.Configure<VnpayOptions>(builder.Configuration.GetSection("Vnpay"));
builder.Services.Configure<BankTransferOptions>(builder.Configuration.GetSection("BankTransfer"));
builder.Services.AddHttpClient().ConfigureHttpClientDefaults(b => b.ConfigurePrimaryHttpMessageHandler(() => new DenyExternalHttpHandler()));
builder.Services.AddChatbot(builder.Configuration);
builder.Services.ConfigureAll<Microsoft.Extensions.Http.HttpClientFactoryOptions>(o =>
    o.HttpMessageHandlerBuilderActions.Add(b => b.PrimaryHandler = new DenyExternalHttpHandler()));
builder.Services.AddScoped<FirebaseNotificationSender>();
builder.Services.Configure<CloudinaryOptions>(builder.Configuration.GetSection("Cloudinary"));
builder.Services.AddHttpClient<CloudinaryImageStorage>().ConfigurePrimaryHttpMessageHandler(() => new DenyExternalHttpHandler());
builder.Services.AddSingleton<VnpayService>();
builder.Services.AddScoped<AvailabilityService>();
// ReservationExpirationService is not started by this guarded preparation runtime.
// NotificationDeliveryWorker is not started by this guarded preparation runtime.
// ReturnReminderWorker is not started by this guarded preparation runtime.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Rental Camera API",
        Version = "v1",
        Description = "API nghiệp vụ dùng chung cho web và mobile Rental Camera."
    });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "Token nội bộ",
        In = ParameterLocation.Header,
        Description = "Dán accessToken nhận từ POST /api/auth/login."
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
        }] = Array.Empty<string>()
    });
});
builder.Services.AddAuthentication("Bearer")
    .AddScheme<AuthenticationSchemeOptions, BearerTokenHandler>("Bearer", _ => { });
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Customer", policy => policy.RequireRole("KHACH_HANG"));
    options.AddPolicy("Staff", policy => policy.RequireRole("NHAN_VIEN", "ADMIN"));
    options.AddPolicy("Admin", policy => policy.RequireRole("ADMIN"));
});
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("vnpay-query", context => RateLimitPartition.GetFixedWindowLimiter(
        $"{context.Connection.RemoteIpAddress}|{context.Request.RouteValues["id"]}",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 1,
            Window = TimeSpan.FromMinutes(5),
            QueueLimit = 0
        }));
    options.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 5,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        }));
    options.AddPolicy("chatbot", context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 3, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});

var app = builder.Build();
app.UseConcurrencyResponse();
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors("Frontend");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

if (args.Length == 2 && args[0] == "set-password")
{
    if (Console.IsInputRedirected)
        throw new InvalidOperationException("Lệnh đặt mật khẩu chỉ chạy trong cửa sổ terminal tương tác.");
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
    var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher<TaiKhoan>>();
    var account = await db.TaiKhoan.SingleOrDefaultAsync(x => x.TenDangNhap == args[1]);
    if (account is null)
    {
        Console.WriteLine("Không tìm thấy tài khoản.");
        return;
    }
    Console.Write("Mật khẩu mới (8–128 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt): ");
    var password = new System.Text.StringBuilder();
    while (true)
    {
        var key = Console.ReadKey(intercept: true);
        if (key.Key == ConsoleKey.Enter) break;
        if (key.Key == ConsoleKey.Backspace && password.Length > 0) password.Length--;
        else if (!char.IsControl(key.KeyChar) && password.Length < 128) password.Append(key.KeyChar);
    }
    Console.WriteLine();
    if (!PasswordPolicy.IsValid(password.ToString()))
    {
        Console.WriteLine($"{PasswordPolicy.Description} Chưa thay đổi dữ liệu.");
        return;
    }
    account.MatKhauHash = hasher.HashPassword(account, password.ToString());
    account.PhienBanBaoMat=checked(account.PhienBanBaoMat+1);
    await db.SaveChangesAsync();
    Console.WriteLine("Đã đặt mật khẩu cho tài khoản. Không dùng lại mật khẩu mẫu.");
    return;
}

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));
app.MapGet("/api/dieu-khoan/hien-hanh", () => Results.Ok(new {
    phienBan=RentalPolicy.TermsVersion, noiDung=RentalPolicy.Terms, muiGio="Asia/Ho_Chi_Minh"
}));
app.MapAuthEndpoints();
app.MapNotificationEndpoints();
app.MapFcmTokenEndpoints();
app.MapCatalogEndpoints();
app.MapChatbotEndpoints(); // Gate remains disabled; external HTTP is blocked for every named client.
app.MapEquipmentEndpoints();
app.MapRentalEndpoints();
app.MapCartEndpoints();
app.MapIdentityEndpoints();
app.MapContractEndpoints();
app.MapRenewalEndpoints();
app.MapCancellationEndpoints();
BranchWorkingHours.MapWorkingHoursEndpoints(app);
app.MapNoShowEndpoints();
LateReturnService.MapLateReturnEndpoints(app);
app.MapReturnTimeCorrectionEndpoints();
app.MapVnpayEndpoints();
app.MapRefundEndpoints();
app.MapTrialMedia();
app.MapPenaltyEndpoints();
app.MapHandoverEndpoints();
app.MapSettlementEndpoints();
app.MapReviewEndpoints();
app.MapReportEndpoints();

app.Run();
