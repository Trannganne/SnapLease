using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using RentalCamera.Api.Email;

namespace Schema33HttpRegression;

public static class Harness
{
    public static async Task<int> LegacyMain(string[] args)
    {
        if (args.Length != 1 || string.IsNullOrWhiteSpace(args[0]))
            throw new ArgumentException("Expected one synthetic contract id.");

        var contractId = args[0];
        await using var factory = new WebApplicationFactory<global::Program>();
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });

        using var login = await client.PostAsJsonAsync("/api/auth/login", new
        {
            tenDangNhap = "trial33.customer02",
            matKhau = "TrialOnly!2026a"
        });
        Require(login.StatusCode == HttpStatusCode.OK, "fixture login");
        using var loginJson = JsonDocument.Parse(await login.Content.ReadAsStringAsync());
        var token = loginJson.RootElement.GetProperty("accessToken").GetString();
        Require(!string.IsNullOrWhiteSpace(token), "access token");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var request = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/yeu-cau-ky", new
        {
            daDongYDieuKhoan = true
        });
        Require(request.StatusCode == HttpStatusCode.Accepted, "signature request");
        using var requestJson = JsonDocument.Parse(await request.Content.ReadAsStringAsync());
        var confirmationId = requestJson.RootElement.GetProperty("maXacNhan").GetString();
        Require(!string.IsNullOrWhiteSpace(confirmationId), "signature confirmation id");
        Require(requestJson.RootElement.GetProperty("maOtp").ValueKind == JsonValueKind.Null,
            "OTP must not be exposed through HTTP");

        var mailbox = factory.Services.GetRequiredService<FakeTrialSender>();
        if (!mailbox.TryTake(out var message) || message is null)
            throw new InvalidOperationException("FAIL fake mailbox message");
        Require(message.Purpose == "CONTRACT_OTP:" + contractId, "mailbox purpose binding");
        Require(message.Value.Length == 6 && message.Value.All(char.IsDigit), "mailbox OTP format");

        using var sign = await client.PutAsJsonAsync($"/api/hop-dong/{contractId}/ky", new
        {
            maXacNhan = confirmationId,
            maOtp = message.Value,
            daDongYDieuKhoan = true
        });
        Require(sign.StatusCode == HttpStatusCode.OK, "contract signing");

        using var readback = await client.GetAsync($"/api/hop-dong/{contractId}");
        Require(readback.StatusCode == HttpStatusCode.OK, "signed contract readback");
        using var contractJson = JsonDocument.Parse(await readback.Content.ReadAsStringAsync());
        Require(contractJson.RootElement.GetProperty("trangThai").GetString() == "DA_KY",
            "signed contract status");

        Console.WriteLine("PASS signature request, DI-only OTP retrieval, signing and DA_KY readback; OTP not printed.");
        return 0;
    }

    private static void Require(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException("FAIL " + name);
    }
}
