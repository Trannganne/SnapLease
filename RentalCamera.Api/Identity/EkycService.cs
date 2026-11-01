using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Identity;

public sealed class EkycOptions
{
    public const string SectionName = "Ekyc";
    public bool Enabled { get; set; }
    public string Provider { get; set; } = "Gateway";
    public string VerificationUrl { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public decimal MinimumOcrConfidence { get; set; } = 0.85m;
    public decimal MinimumFaceMatchScore { get; set; } = 0.80m;
    public decimal MinimumLivenessScore { get; set; } = 0.80m;
    public int MaximumImageMegabytes { get; set; } = 10;
}

public sealed record EkycImage(byte[] Bytes, string ContentType);
public sealed record EkycVerificationInput(
    string DocumentType, string ExpectedDocumentNumber,
    EkycImage Front, EkycImage Back, EkycImage Selfie);
public sealed record EkycProviderResult(
    string ReferenceId, string? DocumentNumber, bool DocumentValid,
    bool FaceMatched, bool LivenessPassed, decimal? OcrConfidence,
    decimal? FaceMatchScore, decimal? LivenessScore);
public sealed record EkycDecision(bool Passed, string Status, string? Reason);

public interface IEkycProvider
{
    string Name { get; }
    Task<EkycProviderResult> VerifyAsync(EkycVerificationInput input, CancellationToken ct);
}

public sealed class EkycUnavailableException(string message) : Exception(message);

public static class EkycDecisionPolicy
{
    public static EkycDecision Evaluate(
        EkycProviderResult result, string expectedDocumentNumber, EkycOptions options)
    {
        if (!ValidScore(result.OcrConfidence) || !ValidScore(result.FaceMatchScore) || !ValidScore(result.LivenessScore))
            return new(false, "LOI_NHA_CUNG_CAP", "Nhà cung cấp trả về điểm tin cậy không hợp lệ.");
        if (!result.DocumentValid)
            return new(false, "KHONG_DAT", "Giấy tờ không hợp lệ hoặc không đọc được.");
        if (string.IsNullOrWhiteSpace(result.DocumentNumber) ||
            !string.Equals(Normalize(result.DocumentNumber), Normalize(expectedDocumentNumber), StringComparison.Ordinal))
            return new(false, "KHONG_DAT", "Số giấy tờ OCR không khớp hồ sơ.");
        if (!result.FaceMatched || result.FaceMatchScore is null || result.FaceMatchScore < options.MinimumFaceMatchScore)
            return new(false, "KHONG_DAT", "Khuôn mặt selfie không khớp giấy tờ.");
        if (!result.LivenessPassed || result.LivenessScore is null || result.LivenessScore < options.MinimumLivenessScore)
            return new(false, "KHONG_DAT", "Không đạt kiểm tra người thật.");
        if (result.OcrConfidence is null || result.OcrConfidence < options.MinimumOcrConfidence)
            return new(false, "KHONG_DAT", "Độ tin cậy OCR chưa đạt ngưỡng.");
        return new(true, "DAT", null);
    }

    private static string Normalize(string value) =>
        new(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());
    private static bool ValidScore(decimal? value) => value is null || value is >= 0m and <= 1m;
}

public sealed class DisabledEkycProvider : IEkycProvider
{
    public string Name => "DISABLED";
    public Task<EkycProviderResult> VerifyAsync(EkycVerificationInput input, CancellationToken ct) =>
        throw new EkycUnavailableException("eKYC chưa được cấu hình nhà cung cấp.");
}

// Adapter for a private provider gateway. Vendor-specific credentials and payloads stay outside this API.
public sealed class HttpJsonEkycProvider(
    IHttpClientFactory clients, IOptions<EkycOptions> options) : IEkycProvider
{
    private readonly EkycOptions _options = options.Value;
    public string Name => string.IsNullOrWhiteSpace(_options.Provider) ? "Gateway" : _options.Provider.Trim();

    public async Task<EkycProviderResult> VerifyAsync(EkycVerificationInput input, CancellationToken ct)
    {
        if (!_options.Enabled || !Uri.TryCreate(_options.VerificationUrl, UriKind.Absolute, out var endpoint) || endpoint.Scheme != Uri.UriSchemeHttps)
            throw new EkycUnavailableException("eKYC chưa được cấu hình HTTPS hợp lệ.");

        var client = clients.CreateClient("EkycGateway");
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = JsonContent.Create(new GatewayRequest(
                input.DocumentType, input.ExpectedDocumentNumber,
                ToDataUri(input.Front), ToDataUri(input.Back), ToDataUri(input.Selfie)))
        };
        if (!string.IsNullOrWhiteSpace(_options.ApiKey))
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);

        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        if (!response.IsSuccessStatusCode)
            throw new EkycUnavailableException($"Nhà cung cấp eKYC trả về HTTP {(int)response.StatusCode}.");
        var payload = await response.Content.ReadFromJsonAsync<GatewayResponse>(cancellationToken: ct)
            ?? throw new EkycUnavailableException("Phản hồi eKYC rỗng.");
        if (string.IsNullOrWhiteSpace(payload.ReferenceId))
            throw new EkycUnavailableException("Phản hồi eKYC thiếu mã tham chiếu.");

        return new(payload.ReferenceId, payload.DocumentNumber, payload.DocumentValid,
            payload.FaceMatched, payload.LivenessPassed, payload.OcrConfidence,
            payload.FaceMatchScore, payload.LivenessScore);
    }

    private static string ToDataUri(EkycImage image) =>
        $"data:{image.ContentType};base64,{Convert.ToBase64String(image.Bytes)}";

    private sealed record GatewayRequest(
        string DocumentType, string ExpectedDocumentNumber,
        string FrontImage, string BackImage, string SelfieImage);
    private sealed record GatewayResponse(
        string ReferenceId, string? DocumentNumber, bool DocumentValid,
        bool FaceMatched, bool LivenessPassed, decimal? OcrConfidence,
        decimal? FaceMatchScore, decimal? LivenessScore);
}
