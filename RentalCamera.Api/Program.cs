using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.OpenApi.Models;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Catalog;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Equipment;
using RentalCamera.Api.Handover;
using RentalCamera.Api.Identity;
using RentalCamera.Api.Notifications;
using RentalCamera.Api.Penalties;
using RentalCamera.Api.Rental;
using RentalCamera.Api.Reports;
using RentalCamera.Api.Reviews;
using RentalCamera.Api.Settlement;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

var connectionString = builder.Configuration.GetConnectionString("RentalCamera")
    ?? throw new InvalidOperationException("Thiếu ConnectionStrings:RentalCamera.");
builder.Services.AddDbContext<RentalCameraContext>(options => options.UseSqlServer(connectionString));
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
builder.Services.AddScoped<AvailabilityService>();
builder.Services.AddHostedService<ReservationExpirationService>();
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
    options.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 5,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        }));
});

var app = builder.Build();
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
    await db.SaveChangesAsync();
    Console.WriteLine("Đã đặt mật khẩu cho tài khoản. Không dùng lại mật khẩu mẫu.");
    return;
}

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));
app.MapAuthEndpoints();
app.MapNotificationEndpoints();
app.MapCatalogEndpoints();
app.MapEquipmentEndpoints();
app.MapRentalEndpoints();
app.MapIdentityEndpoints();
app.MapContractEndpoints();
app.MapPenaltyEndpoints();
app.MapHandoverEndpoints();
app.MapSettlementEndpoints();
app.MapReviewEndpoints();
app.MapReportEndpoints();

app.Run();
