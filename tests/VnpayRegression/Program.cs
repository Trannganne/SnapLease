using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Payments;

const string secret = "regression-test-secret";
var handler = new QueryHandler();
var service = new VnpayService(Options.Create(new VnpayOptions {
    Enabled = true, TmnCode = "TEST", HashSecret = secret,
    ReturnUrl = "https://example.test/return"
}), new ClientFactory(handler));
var fields = new Dictionary<string, string> {
    ["vnp_ResponseId"] = "response", ["vnp_Command"] = "querydr",
    ["vnp_ResponseCode"] = "00", ["vnp_Message"] = "OK",
    ["vnp_TmnCode"] = "TEST", ["vnp_TxnRef"] = "REF",
    ["vnp_Amount"] = "300000000", ["vnp_BankCode"] = "NCB",
    // Synthetic gateway fixture; never use a customer's transaction in shared tests.
    ["vnp_PayDate"] = "20260101100000", ["vnp_TransactionNo"] = "123456789012345",
    ["vnp_TransactionType"] = "01", ["vnp_TransactionStatus"] = "00",
    ["vnp_OrderInfo"] = "test", ["vnp_PromotionCode"] = "", ["vnp_PromotionAmount"] = ""
};
void Sign() {
    var values = fields.Where(x => x.Key != "vnp_SecureHash").Select(x => x.Value);
    fields["vnp_SecureHash"] = Convert.ToHexString(HMACSHA512.HashData(
        Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(string.Join('|', values)))).ToLowerInvariant();
    handler.Response = JsonSerializer.Serialize(fields);
}
async Task<VnpayQueryDrResult> Query() => await service.QueryTransactionAsync(
    "REF", new DateTime(2026, 10, 12, 12, 27, 41, DateTimeKind.Unspecified), "127.0.0.1");
void Check(bool condition, string name) { if (!condition) throw new Exception(name); Console.WriteLine("PASS " + name); }
Sign();
Check((await Query()).Success, "valid signed success");
Check(handler.TransactionDate == "20261012192741", "SQL unspecified UTC converted to GMT+7");
Check(handler.UserAgent == "SnapLease/1.0", "QueryDR sends gateway-required User-Agent");
fields.Remove("vnp_SecureHash"); handler.Response = JsonSerializer.Serialize(fields);
Check((await Query()).ErrorDetail == "MissingSignature", "missing signature rejected");
fields["vnp_TmnCode"] = "OTHER"; Sign();
Check((await Query()).ErrorDetail == "InvalidMerchant", "wrong merchant rejected");
fields["vnp_TmnCode"] = "TEST"; fields["vnp_TxnRef"] = "OTHER"; Sign();
Check((await Query()).ErrorDetail == "InvalidTxnRef", "wrong reference rejected");
fields["vnp_TxnRef"] = "REF"; Sign(); fields["vnp_Amount"] = "1";
handler.Response = JsonSerializer.Serialize(fields);
Check((await Query()).ErrorDetail == "InvalidSignature", "tampered amount rejected");
fields["vnp_Amount"] = ""; Sign();
Check((await Query()).ErrorDetail == "InvalidTransaction", "missing amount rejected");
handler.Response = "{\"vnp_ResponseCode\":\"94\"}";
var duplicate = await Query();
Check(!duplicate.Success && duplicate.ErrorDetail == "QueryDrRejected", "duplicate query is unknown, not merchant mismatch");

sealed class ClientFactory(QueryHandler handler) : IHttpClientFactory {
    public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
}
sealed class QueryHandler : HttpMessageHandler {
    public string Response = "{}";
    public string? TransactionDate;
    public string? UserAgent;
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) {
        using var doc = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct));
        TransactionDate = doc.RootElement.GetProperty("vnp_TransactionDate").GetString();
        UserAgent = request.Headers.UserAgent.ToString();
        return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(Response, Encoding.UTF8, "application/json") };
    }
}
