using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Identity;

var handler = new ProviderHandler();
var options = new VnptEkycOptions
{
    Enabled = true,
    LiveApiApproved = true,
    TokenId = "test-id",
    TokenKey = "test-key",
    AccessToken = "test-access",
    FaceMatchThreshold = 0.80m
};
var http = new HttpClient(handler) { BaseAddress = new Uri(VnptEkycOptions.ApprovedBaseUrl) };
var service = new VnptEkycService(http, Options.Create(options));
var image = new VnptImage(Png(720, 1080), "image/png");

void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine("PASS " + name);
}

var result = await service.VerifyAsync(image, image, image, "001234567890", CancellationToken.None);
Check(result.Outcome == "DAT", "matching OCR, face and liveness produce automatic pass");
Check(result.DocumentNumberMatches && result.FaceMatches && result.IsLive,
    "document number, face and liveness pass are preserved");
Check(result.OcrConfidence == 0.95m && result.FaceScore == 0.92m, "provider scores are normalized to zero-to-one");
Check(result.LivenessScore == 1m, "successful liveness is persisted as a normalized score");
Check(handler.UploadCount == 3 && handler.OcrCount == 1 && handler.CompareCount == 1 && handler.LivenessCount == 1,
    "verification uses exactly three uploads, one OCR, one face comparison and one liveness check");
Check(handler.HeadersValid, "every provider request carries required secrets without query-string exposure");
Check(handler.UploadMacHeaderAbsent && handler.AiMacHeaderPresent,
    "mac-address is limited to documented AI requests");

handler.FaceMatches = false;
var mismatch = await service.VerifyAsync(image, image, image, "001234567890", CancellationToken.None);
Check(mismatch.Outcome == "KHONG_DAT" && !mismatch.FaceMatches,
    "face mismatch cannot become an automatic pass");

handler.FaceMatches = true;
handler.IsLive = false;
var notLive = await service.VerifyAsync(image, image, image, "001234567890", CancellationToken.None);
Check(notLive.Outcome == "KHONG_DAT" && !notLive.IsLive && notLive.LivenessScore == 0m,
    "failed liveness cannot become an automatic pass");

var callsBeforeInvalidImage = handler.TotalCount;
try
{
    await service.VerifyAsync(new VnptImage(Png(599, 899), "image/png"), image, image,
        "001234567890", CancellationToken.None);
    throw new Exception("small image accepted");
}
catch (VnptEkycException failure)
{
    Check(failure.Code == "VNPT_IMAGE_RESOLUTION" && handler.TotalCount == callsBeforeInvalidImage,
        "invalid resolution is rejected before spending provider quota");
}

options.Enabled = false;
Check(service.UnavailableReason is not null, "disabled integration fails closed");
options.Enabled = true;
options.BaseUrl = "https://example.test/";
Check(service.UnavailableReason?.Contains("miền đã duyệt", StringComparison.Ordinal) == true,
    "unapproved provider host fails closed");
options.BaseUrl = VnptEkycOptions.ApprovedBaseUrl;
options.AccessToken = "SET_WITH_ENVIRONMENT_VARIABLE_ONLY";
Check(service.UnavailableReason?.Contains("Thiếu Token", StringComparison.Ordinal) == true,
    "configuration placeholders are never accepted as credentials");
Console.WriteLine("PASS VNPT eKYC adapter regression; no live provider call was made.");

static byte[] Png(int width, int height)
{
    var bytes = new byte[36];
    byte[] signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    signature.CopyTo(bytes, 0);
    bytes[12] = 0x49; bytes[13] = 0x48; bytes[14] = 0x44; bytes[15] = 0x52;
    System.Buffers.Binary.BinaryPrimitives.WriteInt32BigEndian(bytes.AsSpan(16, 4), width);
    System.Buffers.Binary.BinaryPrimitives.WriteInt32BigEndian(bytes.AsSpan(20, 4), height);
    bytes[^8] = 0x49; bytes[^7] = 0x45; bytes[^6] = 0x4E; bytes[^5] = 0x44;
    return bytes;
}

sealed class ProviderHandler : HttpMessageHandler
{
    public int UploadCount { get; private set; }
    public int OcrCount { get; private set; }
    public int CompareCount { get; private set; }
    public int LivenessCount { get; private set; }
    public int TotalCount => UploadCount + OcrCount + CompareCount + LivenessCount;
    public bool HeadersValid { get; private set; } = true;
    public bool UploadMacHeaderAbsent { get; private set; } = true;
    public bool AiMacHeaderPresent { get; private set; } = true;
    public bool FaceMatches { get; set; } = true;
    public bool IsLive { get; set; } = true;

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        HeadersValid &= request.Headers.Authorization?.Scheme == "Bearer" &&
            request.Headers.Authorization.Parameter == "test-access" &&
            request.Headers.GetValues("Token-id").Single() == "test-id" &&
            request.Headers.GetValues("Token-key").Single() == "test-key" &&
            string.IsNullOrEmpty(request.RequestUri!.Query);
        string response;
        if (request.RequestUri!.AbsolutePath == "/file-service/v1/addFile")
        {
            UploadCount++;
            UploadMacHeaderAbsent &= !request.Headers.Contains("mac-address");
            response = JsonSerializer.Serialize(new
            {
                message = "IDG-00000000",
                @object = new { hash = $"hash-{UploadCount}" }
            });
        }
        else if (request.RequestUri.AbsolutePath == "/ai/v1/ocr/id")
        {
            OcrCount++;
            AiMacHeaderPresent &= request.Headers.GetValues("mac-address").Single() == "TEST1";
            response = "{\"message\":\"IDG-00000000\",\"object\":{\"citizen_id\":\"001234567890\",\"id_probs\":\"[0.9,1.0]\"}}";
        }
        else if (request.RequestUri.AbsolutePath == "/ai/v1/face/compare")
        {
            CompareCount++;
            AiMacHeaderPresent &= request.Headers.GetValues("mac-address").Single() == "TEST1";
            response = FaceMatches
                ? "{\"message\":\"IDG-00000000\",\"object\":{\"msg\":\"MATCH\",\"prob\":92}}"
                : "{\"message\":\"IDG-00000000\",\"object\":{\"msg\":\"NOMATCH\",\"prob\":58}}";
        }
        else if (request.RequestUri.AbsolutePath == "/ai/v1/face/liveness")
        {
            LivenessCount++;
            AiMacHeaderPresent &= request.Headers.GetValues("mac-address").Single() == "TEST1";
            response = IsLive
                ? "{\"message\":\"IDG-00000000\",\"object\":{\"liveness\":\"success\",\"liveness_msg\":\"Real people\",\"is_eye_open\":\"yes\"}}"
                : "{\"message\":\"IDG-00000000\",\"object\":{\"liveness\":\"failure\",\"liveness_msg\":\"Not real people\",\"is_eye_open\":\"no\"}}";
        }
        else throw new Exception("Unexpected provider path: " + request.RequestUri.AbsolutePath);
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(response, Encoding.UTF8, "application/json")
        });
    }
}
