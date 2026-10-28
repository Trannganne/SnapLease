using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Data;

namespace Schema33HttpRegression;

public static class RemainingCoverageHarness
{
    private const string Password = "TrialOnly!2026a";

    public static async Task<int> VerifyCredentialsAsync()
    {
        await using var factory = new WebApplicationFactory<global::Program>();
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        var names = Enumerable.Range(1, 12).Select(i => $"trial33.customer{i:00}")
            .Concat(new[] { "trial33.staff01", "trial33.staff02", "trial33.staff03", "trial33.admin" }).ToArray();
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher<TaiKhoan>>();
        var accounts = await db.TaiKhoan.AsNoTracking().Where(x => names.Contains(x.TenDangNhap)).ToListAsync();
        var failures = names.Where(name =>
        {
            var account = accounts.SingleOrDefault(x => x.TenDangNhap == name);
            return account == null || hasher.VerifyHashedPassword(account, account.MatKhauHash, Password) == PasswordVerificationResult.Failed;
        }).ToArray();
        Require(failures.Length == 0, "fixture hashes: " + string.Join(',', failures));
        using var login = await client.PostAsJsonAsync("/api/auth/login", new { tenDangNhap = "trial33.customer01", matKhau = Password });
        Require(login.StatusCode == HttpStatusCode.OK, "customer01 HTTP login after hash correction");
        Console.WriteLine("PASS all 16 fixture password hashes and customer01 HTTP login on clean Schema33 database.");
        return 0;
    }

    public static async Task<int> RunAsync(string cancellableContractId, string staffCancellationId, string adminCancellationId)
    {
        await using var factory = new WebApplicationFactory<global::Program>();
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

        var fixtureNames = Enumerable.Range(1, 12).Select(i => $"trial33.customer{i:00}")
            .Concat(new[] { "trial33.staff01", "trial33.staff02", "trial33.staff03", "trial33.admin" })
            .ToArray();
        var failedLogins = new List<string>();
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
            var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher<TaiKhoan>>();
            var accounts = await db.TaiKhoan.AsNoTracking().Where(x => fixtureNames.Contains(x.TenDangNhap)).ToListAsync();
            foreach (var name in fixtureNames)
            {
                var account = accounts.SingleOrDefault(x => x.TenDangNhap == name);
                if (account == null) failedLogins.Add(name + ":missing");
                else if (hasher.VerifyHashedPassword(account, account.MatKhauHash, Password) == PasswordVerificationResult.Failed)
                    failedLogins.Add(name + ":bad-hash");
            }
        }
        Console.WriteLine($"RESULT fixture password hashes {fixtureNames.Length - failedLogins.Count}/{fixtureNames.Length}; failures={string.Join(',', failedLogins)}");
        var tokenIssuer = factory.Services.GetRequiredService<TokenIssuer>();
        var customerToken = tokenIssuer.Issue("TR33_C02", 0);
        var otherCustomerToken = tokenIssuer.Issue("TR33_C03", 0);
        var staffToken = tokenIssuer.Issue("TR33_N01", 0);
        var otherBranchStaffToken = tokenIssuer.Issue("TR33_N02", 0);
        var adminToken = tokenIssuer.Issue("TR33_N04", 0);

        // Legacy self-cancellation while the contract is still CHO_KY.
        SetToken(client, customerToken);
        var unsignedId = await CreateUnsignedContractAsync(client);
        SetToken(client, otherCustomerToken);
        using (var foreignCancel = await client.PostAsync($"/api/hop-dong/{unsignedId}/huy", null))
            Require(foreignCancel.StatusCode == HttpStatusCode.NotFound, "other customer cannot cancel unsigned contract");
        SetToken(client, customerToken);
        using (var ownerCancel = await client.PostAsync($"/api/hop-dong/{unsignedId}/huy", null))
        {
            Require(ownerCancel.StatusCode == HttpStatusCode.OK, "owner unsigned cancellation");
            using var json = JsonDocument.Parse(await ownerCancel.Content.ReadAsStringAsync());
            Require(json.RootElement.GetProperty("trangThai").GetString() == "DA_HUY", "unsigned contract cancelled status");
        }
        using (var replay = await client.PostAsync($"/api/hop-dong/{unsignedId}/huy", null))
            Require(replay.StatusCode == HttpStatusCode.OK, "unsigned cancellation replay");
        using (var paymentAfterCancel = await client.PostAsJsonAsync($"/api/hop-dong/{unsignedId}/thanh-toan-coc",
                   new { phuongThuc = "TIEN_MAT", noiDungChuyenKhoan = (string?)null }))
            Require(paymentAfterCancel.StatusCode == HttpStatusCode.Conflict, "payment blocked after unsigned cancellation");

        // Financial cancellation before handover: collect deposit, cancel, create/confirm/ack refund.
        SetToken(client, otherCustomerToken);
        using (var foreignDirect = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao",
                   new { lyDo = "Không thuộc hợp đồng", operationId = "schema33-cancel-foreign-" + Guid.NewGuid().ToString("N") }))
            Require(foreignDirect.StatusCode == HttpStatusCode.Forbidden, "other customer direct cancellation forbidden");

        SetToken(client, customerToken);
        using (var invalidException = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao",
                   new { lyDo = "Không hợp lệ", operationId = "schema33-cancel-invalid-" + Guid.NewGuid().ToString("N"), canCuNgoaiLe = "LOI_CUA_HANG" }))
            Require(invalidException.StatusCode == HttpStatusCode.BadRequest, "customer cannot claim staff exception");

        string paymentId;
        using (var createDeposit = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/thanh-toan-coc",
                   new { phuongThuc = "TIEN_MAT", noiDungChuyenKhoan = (string?)null }))
        {
            Require(createDeposit.StatusCode == HttpStatusCode.Created, "cancellation deposit creation");
            using var json = JsonDocument.Parse(await createDeposit.Content.ReadAsStringAsync());
            paymentId = json.RootElement.GetProperty("maThanhToan").GetString()!;
            Require(!string.IsNullOrWhiteSpace(paymentId), "cancellation deposit id");
        }
        SetToken(client, staffToken);
        using (var confirmDeposit = await client.PostAsJsonAsync($"/api/thanh-toan/{paymentId}/xac-nhan",
                   new { thanhCong = true, maGiaoDich = (string?)null }))
            Require(confirmDeposit.StatusCode == HttpStatusCode.OK, "cancellation deposit confirmation");

        var cancelOperation = "schema33-cancel-owner-" + Guid.NewGuid().ToString("N");
        SetToken(client, customerToken);
        using (var cancel = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao",
                   new { lyDo = "Thay đổi kế hoạch thuê", operationId = cancelOperation }))
        {
            Require(cancel.StatusCode == HttpStatusCode.OK, "paid contract direct cancellation");
            using var json = JsonDocument.Parse(await cancel.Content.ReadAsStringAsync());
            Require(json.RootElement.GetProperty("trangThai").GetString() == "DA_HUY", "paid contract cancelled status");
        }
        using (var replay = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao",
                   new { lyDo = "Thay đổi kế hoạch thuê", operationId = cancelOperation }))
            Require(replay.StatusCode == HttpStatusCode.OK, "direct cancellation idempotent replay");
        using (var mismatch = await client.PostAsJsonAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao",
                   new { lyDo = "Nội dung đã đổi", operationId = cancelOperation }))
            Require(mismatch.StatusCode == HttpStatusCode.Conflict, "direct cancellation replay hash guard");

        string refundId;
        decimal refundAmount;
        string refundHash;
        using (var cancellationView = await client.GetAsync($"/api/hop-dong/{cancellableContractId}/huy-truoc-ban-giao"))
        {
            Require(cancellationView.StatusCode == HttpStatusCode.OK, "cancellation reconciliation view");
            using var json = JsonDocument.Parse(await cancellationView.Content.ReadAsStringAsync());
            Require(json.RootElement.GetProperty("doiSoatHuy").ValueKind == JsonValueKind.Object, "cancellation reconciliation exists");
            var refunds = json.RootElement.GetProperty("hoanTien").EnumerateArray().ToArray();
            Require(refunds.Length == 1, "one cancellation refund created");
            refundId = refunds[0].GetProperty("maThanhToan").GetString()!;
            refundAmount = refunds[0].GetProperty("soTien").GetDecimal();
            Require(refundAmount > 0, "cancellation refund amount positive");
        }

        SetToken(client, staffToken);
        using (var confirmRefund = await client.PutAsJsonAsync($"/api/thanh-toan/{refundId}/xac-nhan-hoan-huy",
                   new { operationId = "schema33-cancel-refund-staff-" + Guid.NewGuid().ToString("N") }))
            Require(confirmRefund.StatusCode == HttpStatusCode.OK, "cancellation refund staff confirmation");

        SetToken(client, customerToken);
        using (var refundView = await client.GetAsync($"/api/hop-dong/{cancellableContractId}/khoan-hoan"))
        {
            Require(refundView.StatusCode == HttpStatusCode.OK, "cancellation refund view");
            using var json = JsonDocument.Parse(await refundView.Content.ReadAsStringAsync());
            var row = json.RootElement.EnumerateArray().Single(x => x.GetProperty("maThanhToan").GetString() == refundId);
            refundHash = row.GetProperty("maBamKhoanHoan").GetString()!;
        }
        using (var wrongAck = await client.PostAsJsonAsync($"/api/thanh-toan/{refundId}/xac-nhan-nhan-hoan",
                   new { operationId = "schema33-cancel-refund-wrong-" + Guid.NewGuid().ToString("N"), soTienXacNhan = refundAmount, maBamKhoanHoan = "WRONG" }))
            Require(wrongAck.StatusCode == HttpStatusCode.Conflict, "cancellation refund hash guard");
        using (var ack = await client.PostAsJsonAsync($"/api/thanh-toan/{refundId}/xac-nhan-nhan-hoan",
                   new { operationId = "schema33-cancel-refund-owner-" + Guid.NewGuid().ToString("N"), soTienXacNhan = refundAmount, maBamKhoanHoan = refundHash }))
            Require(ack.StatusCode == HttpStatusCode.OK, "cancellation refund owner acknowledgement");

        SetToken(client, staffToken);
        using (var oldQueue = await client.GetAsync("/api/yeu-cau-huy/cho-duyet"))
            Require((int)oldQueue.StatusCode == 410, "removed cancellation queue returns 410");
        using (var oldProcess = await client.PutAsJsonAsync("/api/yeu-cau-huy/legacy/xu-ly", new { }))
            Require((int)oldProcess.StatusCode == 410, "removed cancellation processing returns 410");

        // No-show must not cancel a future appointment; Staff/Admin direct exception routes are separately covered.
        using (var contractView = await client.GetAsync($"/api/hop-dong/{staffCancellationId}"))
        {
            Require(contractView.StatusCode == HttpStatusCode.OK, "staff cancellation contract view");
            using var json = JsonDocument.Parse(await contractView.Content.ReadAsStringAsync());
            var handoverAt = json.RootElement.GetProperty("thoiGianBanGiao").GetDateTime();
            using var noShow = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/xac-nhan-khong-den", new
            {
                gioHenDaXacNhan = DateTime.SpecifyKind(handoverAt, DateTimeKind.Unspecified),
                khongCoLichHenMoi = true, cuaHangSanSang = true, khachChuaDen = true, daThuLienHe = true,
                lienHeLucUtc = DateTime.UtcNow.AddMinutes(-1), kenhLienHe = "DIEN_THOAI",
                ketQuaLienHe = "Không liên lạc được", ghiChu = "Synthetic future no-show guard",
                taiLieuUrl = (string?)null, coTranhChap = false, deNghiNgoaiLe = false,
                operationId = "schema33-no-show-future-" + Guid.NewGuid().ToString("N"),
                phienBanXacMinhDaXem = (string?)null
            });
            Require(noShow.StatusCode == HttpStatusCode.Conflict, "future no-show cancellation blocked");
        }
        using (var queue = await client.GetAsync("/api/hop-dong/can-kiem-tra-nhan"))
            Require(queue.StatusCode == HttpStatusCode.OK, "no-show review queue");

        SetToken(client, otherBranchStaffToken);
        using (var crossBranch = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/huy-truc-tiep", new
                   { lyDo = "Sai chi nhánh", operationId = "schema33-staff-cross-" + Guid.NewGuid().ToString("N"), canCuNgoaiLe = "LOI_CUA_HANG", lyDoNgoaiLe = "Synthetic" }))
            Require(crossBranch.StatusCode == HttpStatusCode.Forbidden, "cross-branch direct cancellation forbidden");

        SetToken(client, staffToken);
        using (var missingBasis = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/huy-truc-tiep", new
                   { lyDo = "Thiếu căn cứ", operationId = "schema33-staff-no-basis-" + Guid.NewGuid().ToString("N") }))
            Require(missingBasis.StatusCode == HttpStatusCode.BadRequest, "staff exception basis required");
        using (var staffForceMajeure = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/huy-truc-tiep", new
                   { lyDo = "Vượt quyền", operationId = "schema33-staff-force-" + Guid.NewGuid().ToString("N"), canCuNgoaiLe = "BAT_KHA_KHANG", lyDoNgoaiLe = "Synthetic" }))
            Require(staffForceMajeure.StatusCode == HttpStatusCode.Forbidden, "force majeure requires admin");
        var staffCancelOperation = "schema33-staff-store-fault-" + Guid.NewGuid().ToString("N");
        using (var staffCancel = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/huy-truc-tiep", new
                   { lyDo = "Cửa hàng không thể bàn giao", operationId = staffCancelOperation, canCuNgoaiLe = "LOI_CUA_HANG", lyDoNgoaiLe = "Synthetic store fault" }))
            Require(staffCancel.StatusCode == HttpStatusCode.OK, "staff store-fault cancellation");
        using (var staffReplay = await client.PostAsJsonAsync($"/api/hop-dong/{staffCancellationId}/huy-truc-tiep", new
                   { lyDo = "Cửa hàng không thể bàn giao", operationId = staffCancelOperation, canCuNgoaiLe = "LOI_CUA_HANG", lyDoNgoaiLe = "Synthetic store fault" }))
            Require(staffReplay.StatusCode == HttpStatusCode.OK, "staff cancellation replay");

        SetToken(client, adminToken);
        using (var adminCancel = await client.PostAsJsonAsync($"/api/hop-dong/{adminCancellationId}/huy-truc-tiep", new
                   { lyDo = "Bất khả kháng", operationId = "schema33-admin-force-" + Guid.NewGuid().ToString("N"), canCuNgoaiLe = "BAT_KHA_KHANG", lyDoNgoaiLe = "Synthetic force majeure", taiLieuUrl = "https://example.invalid/schema33-evidence" }))
            Require(adminCancel.StatusCode == HttpStatusCode.OK, "admin force-majeure cancellation");

        Console.WriteLine($"PASS remaining cancellation coverage: unsigned owner cancel/replay, paid pre-handover cancel, reconciliation, refund confirmation/ack, Staff store-fault and Admin force-majeure cancellation, future no-show guard, auth/input/idempotency guards and deprecated 410 routes; unsigned={unsignedId}; paid={cancellableContractId}; staff={staffCancellationId}; admin={adminCancellationId}.");
        if (failedLogins.Count != 0)
            throw new InvalidOperationException("FAIL fixture login set: " + string.Join(", ", failedLogins));
        Console.WriteLine("PASS all 16 fixture password hashes match the declared shared password; HTTP rate limiting was tested separately.");
        return 0;
    }

    private static async Task<string> CreateUnsignedContractAsync(HttpClient client)
    {
        var start = new DateTime(2026, 11, 24, 9, 0, 0);
        var end = new DateTime(2026, 11, 24, 17, 0, 0);
        using var add = await client.PostAsJsonAsync("/api/gio-hang/chi-tiet", new
        {
            maCuaHang = "TR33_S01", maDongMay = "TR33_M04", soLuong = 1,
            ngayBatDau = start, ngayKetThuc = end, phienBan = (Guid?)null
        });
        Require(add.StatusCode == HttpStatusCode.Created, "unsigned cart line");
        using var addJson = JsonDocument.Parse(await add.Content.ReadAsStringAsync());
        var lineId = addJson.RootElement.GetProperty("maChiTietGioHang").GetString();
        var version = addJson.RootElement.GetProperty("phienBan").GetGuid();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/gio-hang/checkout")
        {
            Content = JsonContent.Create(new { items = new[] { new { id = lineId, phienBan = version } } })
        };
        request.Headers.Add("Idempotency-Key", "schema33-cancel-unsigned-" + Guid.NewGuid().ToString("N"));
        using var checkout = await client.SendAsync(request);
        Require(checkout.StatusCode == HttpStatusCode.Created, "unsigned checkout");
        using var holdJson = JsonDocument.Parse(await checkout.Content.ReadAsStringAsync());
        var holdId = holdJson.RootElement.GetProperty("maGiuCho").GetString();
        using var create = await client.PostAsync($"/api/giu-cho/{holdId}/xac-nhan-thue", null);
        Require(create.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created, "unsigned contract creation");
        using var contractJson = JsonDocument.Parse(await create.Content.ReadAsStringAsync());
        return contractJson.RootElement.GetProperty("maHopDong").GetString()!;
    }

    private static void SetToken(HttpClient client, string token) =>
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

    private static void Require(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException("FAIL " + name);
    }
}
