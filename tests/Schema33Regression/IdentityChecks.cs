using System.Data;
using System.Data.Common;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Data;
using RentalCamera.Api.Identity;
using RentalCamera.Api.Notifications;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Email;
using RentalCamera.Api.Infrastructure;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

internal static class IdentityChecks
{
    public static async Task RunRegistrationAsync()
    {
        var count = 0;
        void Check(bool ok, string name) { if (!ok) throw new Exception(name); count++; }
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { Args = [], EnvironmentName = "OfflineRegistration" });
        builder.Configuration.Sources.Clear(); builder.Logging.ClearProviders();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["Schema33Trial:ProviderMode"] = "Fake" });
        builder.Services.AddSingleton<IDataProtectionProvider>(new EphemeralDataProtectionProvider());
        builder.Services.AddScoped<IPasswordHasher<TaiKhoan>, PasswordHasher<TaiKhoan>>();
        builder.Services.AddSingleton<AuthLinkService>(); builder.Services.AddSingleton<TokenIssuer>();
        builder.Services.AddSingleton<PasswordResetTokenService>(); builder.Services.AddSingleton<IAuthEmailSender, FakeTrialSender>();
        builder.Services.AddSingleton(sp => new Schema33TrialGuard(sp.GetRequiredService<IConfiguration>(), builder.Environment));
        var rows = new RegistrationRows();
        builder.Services.AddDbContext<RentalCameraContext>(o => o.UseSqlServer(
            "Server=offline.invalid;Database=OfflineOnly;User ID=offline;Password=offline-only")
            .AddInterceptors(new NoConnection(), rows, new RegistrationSaves(rows), new OfflineTransactions(), new OfflineCommands()));
        await using var app = builder.Build(); app.MapAuthEndpoints();
        var endpoints = ((IEndpointRouteBuilder)app).DataSources.SelectMany(s => s.Endpoints).OfType<RouteEndpoint>().ToArray();
        async Task<int> Invoke(string path, string method, object body)
        {
            using var scope = app.Services.CreateScope();
            var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider,
                User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "OFFLINE_ACCOUNT"),
                    new Claim(ClaimTypes.Role, "KHACH_HANG")], "offline")) };
            context.Request.Method = method; context.Request.ContentType = "application/json";
            context.Features.Set<IHttpRequestBodyDetectionFeature>(new BodyFeature());
            var bytes = JsonSerializer.SerializeToUtf8Bytes(body);
            await using var input = new MemoryStream(bytes); await using var output = new MemoryStream();
            context.Request.Body = input; context.Request.ContentLength = bytes.Length; context.Response.Body = output;
            await endpoints.Single(e => e.RoutePattern.RawText == path &&
                e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains(method)).RequestDelegate!(context);
            return context.Response.StatusCode;
        }
        foreach (var email in new[] { "duplicate@example.invalid", " DUPLICATE@EXAMPLE.INVALID " })
        {
            rows.Reset();
            Check(await Invoke("/api/auth/register", "POST", new RegisterRequest("offline.user", "OfflineOnly!2026a", "0000000000", email)) == 409,
                "Registration rejects an already used unverified mailbox");
            Check(rows.Locks.SequenceEqual(["email:" + AuthLinkService.Fingerprint("DUPLICATE@EXAMPLE.INVALID")]) && rows.Saves == 0,
                "Normalized email lock precedes duplicate lookup and rejection writes nothing");
            rows.Reset();
            Check(await Invoke("/api/auth/email", "PUT", new ChangeEmailRequest(email)) == 409 && rows.Saves == 0,
                "Email update also rejects an unverified mailbox owned by another account");
            Check(rows.Locks.SequenceEqual(["account:OFFLINE_ACCOUNT", "email:" + AuthLinkService.Fingerprint("DUPLICATE@EXAMPLE.INVALID")]),
                "Email update follows the existing account then normalized email lock order");
        }
        rows.Reset();
        Check(await Invoke("/api/auth/email", "PUT", new ChangeEmailRequest(" current@example.invalid ")) == 204 && rows.Saves == 0,
            "Unchanged normalized email preserves existing data and verification epoch");
        rows.Reset(); rows.Duplicate = false;
        Check(await Invoke("/api/auth/register", "POST", new RegisterRequest("offline.new", "OfflineOnly!2026a", "0000000000", " Fresh@Example.invalid ")) == 201 &&
            rows.Saves == 1 && rows.SavedEmail == "FRESH@EXAMPLE.INVALID", "Unused normalized email can register with one suppressed save");
        rows.Reset();
        Check(await Invoke("/api/auth/email", "PUT", new ChangeEmailRequest(" Fresh@Example.invalid ")) == 204 &&
            rows.Saves == 1 && rows.SavedEmail == "FRESH@EXAMPLE.INVALID", "Unused normalized email can update through the existing endpoint");
        Check(AuthLinkService.NormalizeEmail("bad@@example.invalid") == null && AuthLinkService.NormalizeEmail(" x@Example.invalid ") == "X@EXAMPLE.INVALID",
            "Normalization rejects invalid email and folds whitespace/case consistently");
        Console.WriteLine($"PASS {count} registration/email endpoint checks; scripted duplicate rows and transactions, no SQL connection or account mutation. Real SQL locking/concurrency remains unverified.");
    }

    private sealed class RegistrationRows : DbCommandInterceptor
    {
        public List<string> Locks = [];
        public int Saves;
        public bool Duplicate = true;
        public string? SavedEmail;
        public void Reset() { Locks.Clear(); Saves = 0; SavedEmail = null; }
        public override ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(DbCommand command, CommandEventData eventData,
            InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            if (!command.CommandText.Contains("sp_getapplock")) { Saves++; throw new Exception("Unexpected database write"); }
            Locks.Add((string)command.Parameters["@resource"].Value!);
            return ValueTask.FromResult(InterceptionResult<int>.SuppressWithResult(0));
        }
        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(DbCommand command, CommandEventData eventData,
            InterceptionResult<DbDataReader> result, CancellationToken cancellationToken = default)
        {
            var sql = command.CommandText;
            if (!sql.TrimStart().StartsWith("SELECT")) { Saves++; throw new Exception("Unexpected database write"); }
            var table = new DataTable();
            if (sql.Contains("EXISTS"))
            {
                var emailLookup = sql.Contains("[Email]");
                if (emailLookup && (Locks.Count == 0 || !Locks.Last().StartsWith("email:"))) throw new Exception("Missing normalized email lock before lookup");
                if (emailLookup && sql.Contains("EmailXacMinhLucUtc")) throw new Exception("Unverified mailboxes must not be excluded");
                table.Columns.Add("value", typeof(bool)); table.Rows.Add(emailLookup && Duplicate);
            }
            else
            {
                var customer = sql.Contains("[KhachThue]");
                object entity = customer ? new KhachThue { MaKhachThue = "OFFLINE_CUSTOMER", MaTaiKhoan = "OFFLINE_ACCOUNT",
                    Email = "CURRENT@EXAMPLE.INVALID", SoDienThoai = "0000000000" } :
                    new TaiKhoan { MaTaiKhoan = "OFFLINE_ACCOUNT", TenDangNhap = "offline.user", MatKhauHash = "offline-hash", VaiTro = "KHACH_HANG", TrangThai = "HOAT_DONG" };
                var columns = Regex.Matches(sql.Split("FROM", StringSplitOptions.None)[0], @"\[\w+\]\.\[(\w+)\]").Select(m => m.Groups[1].Value).ToArray();
                var values = columns.Select(c => entity.GetType().GetProperty(c)!.GetValue(entity)).ToArray();
                for (var i = 0; i < columns.Length; i++) table.Columns.Add(columns[i], values[i]?.GetType() ?? typeof(string));
                table.Rows.Add(values.Select(v => v ?? DBNull.Value).ToArray());
            }
            return ValueTask.FromResult(InterceptionResult<DbDataReader>.SuppressWithResult(table.CreateDataReader()));
        }
    }
    private sealed class RegistrationSaves(RegistrationRows rows) : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData eventData,
            InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            rows.Saves++;
            rows.SavedEmail = eventData.Context!.ChangeTracker.Entries<KhachThue>().Single().Entity.Email;
            return ValueTask.FromResult(InterceptionResult<int>.SuppressWithResult(1));
        }
    }
    private sealed class OfflineTransactions : DbTransactionInterceptor
    {
        public override ValueTask<InterceptionResult<DbTransaction>> TransactionStartingAsync(DbConnection connection,
            TransactionStartingEventData eventData, InterceptionResult<DbTransaction> result, CancellationToken cancellationToken = default) =>
            ValueTask.FromResult(InterceptionResult<DbTransaction>.SuppressWithResult(new OfflineTransaction(connection, eventData.IsolationLevel)));
    }
    private sealed class OfflineTransaction(DbConnection connection, IsolationLevel isolation) : DbTransaction
    {
        public override IsolationLevel IsolationLevel => isolation;
        protected override DbConnection DbConnection => connection;
        public override void Commit() { }
        public override void Rollback() { }
    }
    private sealed class OfflineCommands : DbCommandInterceptor
    {
        public override InterceptionResult<DbCommand> CommandCreating(CommandCorrelatedEventData eventData, InterceptionResult<DbCommand> result) =>
            InterceptionResult<DbCommand>.SuppressWithResult(new OfflineCommand());
    }
    private sealed class OfflineCommand : DbCommand
    {
        private readonly SqlCommand parameters = new();
        [System.Diagnostics.CodeAnalysis.AllowNull]
        public override string CommandText { get; set; } = "";
        public override int CommandTimeout { get; set; }
        public override CommandType CommandType { get; set; }
        public override bool DesignTimeVisible { get; set; }
        public override UpdateRowSource UpdatedRowSource { get; set; }
        protected override DbConnection? DbConnection { get; set; }
        protected override DbTransaction? DbTransaction { get; set; }
        protected override DbParameterCollection DbParameterCollection => parameters.Parameters;
        protected override DbParameter CreateDbParameter() => new SqlParameter();
        public override void Cancel() { }
        public override void Prepare() { }
        public override int ExecuteNonQuery() => throw new Exception("Unscripted database command forbidden");
        public override object? ExecuteScalar() => throw new Exception("Unscripted database command forbidden");
        protected override DbDataReader ExecuteDbDataReader(CommandBehavior behavior) => throw new Exception("Unscripted database command forbidden");
        protected override void Dispose(bool disposing) { if (disposing) parameters.Dispose(); base.Dispose(disposing); }
    }
    public static async Task RunAsync()
    {
        var count = 0;
        void Check(bool ok, string name) { if (!ok) throw new Exception(name); count++; }
        var root = Path.Combine(Path.GetTempPath(), "offline-identity-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root, "Storage"));
        await File.WriteAllBytesAsync(Path.Combine(root, "Storage", "fixture.jpg"), [0xff, 0xd8, 0xff, 0xd9]);
        try
        {
            var rows = new OfflineRows();
            var saves = new OfflineSaves();
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
                { Args = [], ContentRootPath = root, EnvironmentName = "OfflineIdentityChecks" });
            builder.Configuration.Sources.Clear(); builder.Logging.ClearProviders();
            builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["Schema33Trial:ProviderMode"] = "Fake" });
            builder.Services.AddScoped<FirebaseNotificationSender>();
            builder.Services.AddAuthentication("offline").AddScheme<AuthenticationSchemeOptions, OfflineAuth>("offline", _ => { });
            builder.Services.AddDbContext<RentalCameraContext>(o => o.UseSqlServer(
                "Server=offline.invalid;Database=OfflineOnly;User ID=offline;Password=offline-only")
                .AddInterceptors(new NoConnection(), rows, saves));
            await using var app = builder.Build(); app.MapIdentityEndpoints();
            var endpoints = ((IEndpointRouteBuilder)app).DataSources.SelectMany(s => s.Endpoints).OfType<RouteEndpoint>().ToArray();
            RouteEndpoint Endpoint(string path, string method) => endpoints.Single(e => e.RoutePattern.RawText?.TrimEnd('/') == path.TrimEnd('/') &&
                e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains(method));
            foreach (var (path, method, policy) in new[] {
                ("/api/giay-to", "POST", "Customer"),
                ("/api/giay-to/cua-toi", "GET", "Customer"),
                ("/api/giay-to/{id}/xac-minh", "PUT", "Staff"),
                ("/api/khach-thue/xac-nhan-danh-tinh", "POST", "Customer") })
                Check(Endpoint(path, method).Metadata.GetOrderedMetadata<IAuthorizeData>().Any(p => p.Policy == policy),
                    "Existing identity route keeps its role policy");

            async Task<int> Invoke(string path, string method, string role = "KHACH_HANG", object? body = null, string fileName = "fixture.jpg")
            {
                using var scope = app.Services.CreateScope();
                var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider,
                    User = new ClaimsPrincipal(new ClaimsIdentity([
                        new Claim(ClaimTypes.NameIdentifier, "OFFLINE_ACCOUNT"), new Claim(ClaimTypes.Role, role)], "offline")) };
                context.Request.Method = method;
                context.Request.RouteValues["fileName"] = fileName;
                context.Features.Set<IHttpRequestBodyDetectionFeature>(new BodyFeature());
                context.Request.ContentType = "application/json";
                var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(body));
                await using var input = new MemoryStream(bytes); await using var output = new MemoryStream();
                context.Request.Body = input; context.Request.ContentLength = bytes.Length; context.Response.Body = output;
                await Endpoint(path, method).RequestDelegate!(context);
                return context.Response.StatusCode;
            }

            rows.HasDocument = false;
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET") == 404, "Unlinked file is never exposed");
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET", fileName: "../fixture.jpg") == 404, "Traversal is rejected");
            rows.HasDocument = true; rows.DocumentOwner = "OTHER_CUSTOMER";
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET") == 403, "Customer cannot read another customer's document");
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET", "NHAN_VIEN") == 403, "Staff outside branch scope cannot read document");
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET", "OTHER_ROLE") == 403, "Other roles cannot borrow staff access");
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET", "ADMIN") == 200, "Admin may read linked document");
            rows.DocumentOwner = "OFFLINE_CUSTOMER";
            Check(await Invoke("/api/giay-to/anh/{fileName}", "GET") == 200, "Owner may read own linked document");

            var confirmation = new CustomerIdentityConfirmRequest("OFFLINE_DOC", "DIFFERENT", "Offline fixture",
                new DateOnly(1990, 1, 1), "NAM", "VN", "Offline address", new DateOnly(2020, 1, 1), "Offline issuer");
            Check(await Invoke("/api/khach-thue/xac-nhan-danh-tinh", "POST", body: confirmation) == 400,
                "Confirmation cannot replace the uploaded document number");
            rows.HasDocument = false;
            Check(await Invoke("/api/khach-thue/xac-nhan-danh-tinh", "POST", body: confirmation) == 404,
                "Missing or foreign document cannot be confirmed");
            var malformed = new IdentityDocumentRequest("Offline fixture", "CCCD", "OFFLINE_NUMBER", "data:image/jpeg;base64,not-base64", null);
            Check(await Invoke("/api/giay-to", "POST", body: malformed) == 400, "Malformed image is rejected");
            Check(await Invoke("/api/giay-to", "POST", body: malformed with { MatTruocUrl = "https://external.invalid/image.jpg" }) == 400,
                "External or another customer's image URL is rejected");
            var before = Directory.GetFiles(Path.Combine(root, "Storage")).Length;
            Check(await Invoke("/api/giay-to", "POST", body: malformed with { MatTruocUrl = "data:image/jpeg;base64,/9j/2Q==", MatSauUrl = "data:image/jpeg;base64,bad" }) == 400 &&
                Directory.GetFiles(Path.Combine(root, "Storage")).Length == before,
                "Invalid back image cleans up the new front image");
            Check(rows.Writes == 0, "Rejected requests never write to the database");
            Check(await Invoke("/api/giay-to", "POST", body: new { HoTen = "Offline fixture", LoaiGiayTo = "CCCD",
                SoGiayTo = "OFFLINE_NUMBER", MatTruocUrl = "data:image/jpeg;base64,/9j/2Q==", MatSauUrl = "data:image/jpeg;base64,/9j/2Q==",
                MaKhachThue = "OTHER_CUSTOMER", TrangThaiXacMinh = "HOP_LE" }) == 201 &&
                saves.Document is { MaKhachThue: "OFFLINE_CUSTOMER", TrangThaiXacMinh: "CHO_XAC_MINH" },
                "Upload ignores client owner/approval; server creates pending document for session owner");
            rows.HasDocument = true;
            Check(await Invoke("/api/khach-thue/xac-nhan-danh-tinh", "POST", body: confirmation with { Cccd = "OFFLINE_NUMBER" }) == 200 &&
                saves.CustomerConfirmed && saves.DocumentStatus == "CHO_XAC_MINH",
                "Customer confirmation saves profile without approving the document");
            Console.WriteLine($"PASS {count} identity checks; scripted read results, no SQL connection, real document, provider or runtime request. SQL locking/transactions are not tested.");
        }
        finally { Directory.Delete(root, true); }
    }

    private sealed class BodyFeature : IHttpRequestBodyDetectionFeature { public bool CanHaveBody => true; }
    private sealed class OfflineAuth(IOptionsMonitor<AuthenticationSchemeOptions> o, ILoggerFactory l, UrlEncoder e)
        : AuthenticationHandler<AuthenticationSchemeOptions>(o, l, e)
    { protected override Task<AuthenticateResult> HandleAuthenticateAsync() => Task.FromResult(AuthenticateResult.NoResult()); }
    private sealed class NoConnection : DbConnectionInterceptor
    {
        public override ValueTask<InterceptionResult> ConnectionOpeningAsync(DbConnection connection, ConnectionEventData eventData,
            InterceptionResult result, CancellationToken cancellationToken = default) => ValueTask.FromResult(InterceptionResult.Suppress());
    }
    private sealed class OfflineSaves : SaveChangesInterceptor
    {
        public GiayToTuyThan? Document;
        public bool CustomerConfirmed;
        public string? DocumentStatus;
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData eventData,
            InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            var db = eventData.Context!;
            Document = db.ChangeTracker.Entries<GiayToTuyThan>().Select(e => e.Entity).SingleOrDefault();
            CustomerConfirmed = db.ChangeTracker.Entries<KhachThue>().Any(e => e.Entity.DaXacNhanThongTin);
            DocumentStatus = Document?.TrangThaiXacMinh;
            return ValueTask.FromResult(InterceptionResult<int>.SuppressWithResult(1));
        }
    }
    private sealed class OfflineRows : DbCommandInterceptor
    {
        public bool HasDocument; public string DocumentOwner = "OFFLINE_CUSTOMER"; public int Writes;
        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(DbCommand command, CommandEventData eventData,
            InterceptionResult<DbDataReader> result, CancellationToken cancellationToken = default)
        {
            var sql = command.CommandText;
            if (!sql.TrimStart().StartsWith("SELECT", StringComparison.Ordinal)) { Writes++; throw new Exception("Database writes forbidden in identity checks"); }
            var table = new DataTable();
            if (sql.Contains("EXISTS")) { table.Columns.Add("value", typeof(bool)); table.Rows.Add(false); }
            else
            {
                var values = new Dictionary<string, object?> {
                    ["MaKhachThue"] = sql.Contains("[GiayToTuyThan]") ? DocumentOwner : "OFFLINE_CUSTOMER",
                    ["MaGiayTo"] = "OFFLINE_DOC", ["LoaiGiayTo"] = "CCCD", ["SoGiayTo"] = "OFFLINE_NUMBER",
                    ["MatTruocUrl"] = "/api/giay-to/anh/fixture.jpg", ["MatSauUrl"] = "/api/giay-to/anh/back.jpg",
                    ["NgayTaiLen"] = new DateTime(2030, 1, 1), ["TrangThaiXacMinh"] = "CHO_XAC_MINH", ["GhiChu"] = null,
                    ["MaNhanVien"] = "OFFLINE_STAFF", ["MaCuaHang"] = "OFFLINE_OTHER_BRANCH" };
                foreach (var key in new[] { "MaTaiKhoan", "HoTen", "SoDienThoai", "Email", "CCCD", "DiaChi", "NgaySinh",
                    "GioiTinh", "QuocTich", "NgayCap", "NoiCap", "EmailXacMinhLucUtc" }) values[key] = null;
                values["MaTaiKhoan"] = "OFFLINE_ACCOUNT"; values["SoDienThoai"] = "0000000000";
                values["DaXacNhanThongTin"] = false;
                var columns = Regex.Matches(sql.Split("FROM", StringSplitOptions.None)[0], @"\[\w+\]\.\[(\w+)\]")
                    .Select(m => m.Groups[1].Value).ToArray();
                foreach (var column in columns) table.Columns.Add(column, values[column]?.GetType() ?? typeof(string));
                if (!sql.Contains("[GiayToTuyThan]") || HasDocument)
                    table.Rows.Add(columns.Select(c => values[c] ?? DBNull.Value).ToArray());
            }
            return ValueTask.FromResult(InterceptionResult<DbDataReader>.SuppressWithResult(table.CreateDataReader()));
        }
    }
}
