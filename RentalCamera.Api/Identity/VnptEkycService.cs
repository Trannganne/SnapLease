using System.Buffers.Binary;
using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Identity;

public sealed class VnptEkycService(HttpClient http, IOptions<VnptEkycOptions> configured)
{
    private const int MaximumImageBytes = 5 * 1024 * 1024;
    private const int MaximumResponseBytes = 2 * 1024 * 1024;
    private readonly VnptEkycOptions options = configured.Value;

    public string? UnavailableReason => ValidateConfiguration(options);

    public async Task<VnptIdentityResult> VerifyAsync(
        VnptImage front, VnptImage back, VnptImage selfie,
        string expectedDocumentNumber, CancellationToken ct)
    {
        var unavailable = UnavailableReason;
        if (unavailable is not null) throw new VnptEkycException("VNPT_EKYC_DISABLED", unavailable, 503);

        ValidateImage(front, "Mặt trước CCCD");
        ValidateImage(back, "Mặt sau CCCD");
        ValidateImage(selfie, "Ảnh chân dung");

        var correlationId = $"VNPT-{Guid.NewGuid():N}";
        var clientSession = $"ANDROID_SnapLease_0_Server_1.0_{Guid.NewGuid():N}_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        // VNPT's server-to-server API authenticates through the three headers.
        // The body token is an SDK-generated chain; raw API examples leave it empty.
        // A random GUID is not a valid encrypted chain and is rejected with HTTP 400.
        const string requestToken = "";

        var frontHash = await UploadAsync(front, "cccd-front", correlationId, ct);
        var backHash = await UploadAsync(back, "cccd-back", correlationId, ct);
        var selfieHash = await UploadAsync(selfie, "selfie", correlationId, ct);

        using var ocr = await PostJsonAsync("ai/v1/ocr/id", new
        {
            img_front = frontHash,
            img_back = backHash,
            client_session = clientSession,
            type = -1,
            crop_param = "0.14,0.3",
            validate_postcode = true,
            token = requestToken
        }, ct);
        using var compare = await PostJsonAsync("ai/v1/face/compare", new
        {
            img_front = frontHash,
            img_face = selfieHash,
            client_session = clientSession,
            token = requestToken
        }, ct);

        var ocrObject = RequireSuccessObject(ocr.RootElement, "VNPT_OCR_FAILED");
        var compareObject = RequireSuccessObject(compare.RootElement, "VNPT_FACE_COMPARE_FAILED");
        var extractedNumber = FirstText(ocrObject, "citizen_id", "id") ?? "";
        var faceMessage = FirstText(compareObject, "msg") ?? "";
        var faceScore = NormalizeProbability(ReadDecimal(compareObject, "prob"));
        var ocrConfidence = ReadOcrConfidence(ocrObject);
        var numberMatches = NormalizeDocumentNumber(extractedNumber) == NormalizeDocumentNumber(expectedDocumentNumber);
        var faceMatches = string.Equals(faceMessage, "MATCH", StringComparison.OrdinalIgnoreCase)
            && faceScore is not null && faceScore >= options.FaceMatchThreshold;

        return new VnptIdentityResult(
            correlationId,
            numberMatches && faceMatches ? "CAN_DUYET" : "KHONG_DAT",
            ocrConfidence,
            faceScore,
            extractedNumber.Length > 0,
            numberMatches,
            faceMatches);
    }

    public static string? ValidateConfiguration(VnptEkycOptions value)
    {
        if (!value.Enabled) return "Tích hợp VNPT eKYC chưa được bật.";
        if (!value.LiveApiApproved) return "Lượt gọi VNPT thật chưa được phê duyệt.";
        if (!Uri.TryCreate(value.BaseUrl, UriKind.Absolute, out var baseUri) ||
            baseUri.Scheme != Uri.UriSchemeHttps ||
            !string.Equals(baseUri.Host, "api.idg.vnpt.vn", StringComparison.OrdinalIgnoreCase) ||
            baseUri.AbsolutePath != "/" || baseUri.UserInfo.Length != 0 ||
            baseUri.Query.Length != 0 || baseUri.Fragment.Length != 0)
            return "Base URL VNPT eKYC không thuộc miền đã duyệt.";
        if (!IsConfiguredSecret(value.TokenId) || !IsConfiguredSecret(value.TokenKey) ||
            !IsConfiguredSecret(value.AccessToken))
            return "Thiếu Token ID, Token Key hoặc Access Token VNPT eKYC.";
        if (value.AccessToken.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ||
            value.AccessToken.Any(char.IsWhiteSpace))
            return "Access Token VNPT chỉ được chứa giá trị token, không kèm tiền tố Bearer hoặc khoảng trắng.";
        if (string.IsNullOrWhiteSpace(value.MacAddress) || value.MacAddress.Length > 100)
            return "mac-address VNPT eKYC không hợp lệ.";
        if (value.TimeoutSeconds is < 5 or > 120 || value.FaceMatchThreshold is < 0.5m or > 1m)
            return "Ngưỡng hoặc timeout VNPT eKYC không hợp lệ.";
        return null;
    }

    private static bool IsConfiguredSecret(string value) =>
        !string.IsNullOrWhiteSpace(value) &&
        !value.StartsWith("SET_", StringComparison.OrdinalIgnoreCase) &&
        !value.Contains("PLACEHOLDER", StringComparison.OrdinalIgnoreCase);

    public static void ValidateImage(VnptImage image, string label)
    {
        if (image.Bytes.Length == 0 || image.Bytes.Length > MaximumImageBytes)
            throw new VnptEkycException("VNPT_IMAGE_SIZE", $"{label} phải lớn hơn 0 và không quá 5 MB.", 400);
        if (!TryReadDimensions(image.Bytes, out var width, out var height, out var detectedType) ||
            !string.Equals(detectedType, image.ContentType, StringComparison.OrdinalIgnoreCase))
            throw new VnptEkycException("VNPT_IMAGE_FORMAT", $"{label} chỉ chấp nhận JPEG hoặc PNG hợp lệ.", 400);
        if (Math.Min(width, height) < 600 || Math.Max(width, height) < 900)
            throw new VnptEkycException("VNPT_IMAGE_RESOLUTION", $"{label} phải có độ phân giải tối thiểu 600 x 900.", 400);
    }

    private async Task<string> UploadAsync(VnptImage image, string title, string correlationId, CancellationToken ct)
    {
        using var form = new MultipartFormDataContent();
        using var content = new ByteArrayContent(image.Bytes);
        content.Headers.ContentType = MediaTypeHeaderValue.Parse(image.ContentType);
        form.Add(content, "file", $"{title}.{(image.ContentType == "image/png" ? "png" : "jpg")}");
        form.Add(new StringContent(title), "title");
        form.Add(new StringContent(correlationId), "description");
        using var request = CreateRequest(HttpMethod.Post, "file-service/v1/addFile", form, includeMacAddress: false);
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        using var json = await ReadResponseAsync(response, "VNPT_UPLOAD_FAILED", ct);
        var providerObject = RequireSuccessObject(json.RootElement, "VNPT_UPLOAD_FAILED");
        var hash = FirstText(providerObject, "hash");
        if (string.IsNullOrWhiteSpace(hash))
            throw new VnptEkycException("VNPT_UPLOAD_INVALID", "VNPT không trả về mã ảnh hợp lệ.", 502);
        return hash;
    }

    private async Task<JsonDocument> PostJsonAsync(string path, object body, CancellationToken ct)
    {
        using var content = JsonContent.Create(body);
        using var request = CreateRequest(HttpMethod.Post, path, content, includeMacAddress: true);
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        return await ReadResponseAsync(response, "VNPT_PROVIDER_ERROR", ct);
    }

    private HttpRequestMessage CreateRequest(HttpMethod method, string path, HttpContent content, bool includeMacAddress)
    {
        var request = new HttpRequestMessage(method, path) { Content = content };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.AccessToken.Trim());
        request.Headers.TryAddWithoutValidation("Token-id", options.TokenId.Trim());
        request.Headers.TryAddWithoutValidation("Token-key", options.TokenKey.Trim());
        if (includeMacAddress) request.Headers.TryAddWithoutValidation("mac-address", options.MacAddress.Trim());
        request.Headers.UserAgent.ParseAdd("SnapLease/1.0");
        return request;
    }

    private static async Task<JsonDocument> ReadResponseAsync(
        HttpResponseMessage response, string code, CancellationToken ct)
    {
        if (response.Content.Headers.ContentLength > MaximumResponseBytes)
            throw new VnptEkycException(code, "Phản hồi VNPT vượt giới hạn an toàn.", 502);
        try
        {
            await response.Content.LoadIntoBufferAsync(MaximumResponseBytes);
            if (!response.IsSuccessStatusCode)
            {
                var providerCode = await TryReadProviderErrorCodeAsync(response, ct);
                var suffix = providerCode is null ? "" : $", code {providerCode}";
                throw new VnptEkycException(
                    code,
                    $"VNPT từ chối yêu cầu (HTTP {(int)response.StatusCode}{suffix}).",
                    502);
            }
            return await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        }
        catch (JsonException)
        {
            throw new VnptEkycException(code, "VNPT trả về dữ liệu không hợp lệ.", 502);
        }
    }

    private static async Task<string?> TryReadProviderErrorCodeAsync(
        HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            using var json = await JsonDocument.ParseAsync(
                await response.Content.ReadAsStreamAsync(ct),
                cancellationToken: ct);
            if (!json.RootElement.TryGetProperty("message", out var message) ||
                message.ValueKind != JsonValueKind.String)
                return null;
            var value = message.GetString();
            return string.IsNullOrWhiteSpace(value) || value.Length > 80 ? null : value;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static JsonElement RequireSuccessObject(JsonElement root, string code)
    {
        if (!root.TryGetProperty("message", out var message) || message.GetString() != "IDG-00000000" ||
            !root.TryGetProperty("object", out var providerObject) || providerObject.ValueKind != JsonValueKind.Object)
            throw new VnptEkycException(code, "VNPT không xác nhận xử lý thành công.", 502);
        return providerObject;
    }

    private static string? FirstText(JsonElement value, params string[] names)
    {
        foreach (var name in names)
            if (value.TryGetProperty(name, out var item) && item.ValueKind == JsonValueKind.String &&
                !string.IsNullOrWhiteSpace(item.GetString()) && item.GetString() != "-") return item.GetString();
        return null;
    }

    private static decimal? ReadDecimal(JsonElement value, string name)
    {
        if (!value.TryGetProperty(name, out var item)) return null;
        if (item.ValueKind == JsonValueKind.Number && item.TryGetDecimal(out var number)) return number;
        return item.ValueKind == JsonValueKind.String && decimal.TryParse(
            item.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out number) ? number : null;
    }

    private static decimal? ReadOcrConfidence(JsonElement value)
    {
        if (!value.TryGetProperty("id_probs", out var probs)) return null;
        try
        {
            using var parsed = probs.ValueKind == JsonValueKind.String
                ? JsonDocument.Parse(probs.GetString() ?? "[]")
                : JsonDocument.Parse(probs.GetRawText());
            var values = parsed.RootElement.ValueKind == JsonValueKind.Array
                ? parsed.RootElement.EnumerateArray().Where(x => x.TryGetDecimal(out _)).Select(x => x.GetDecimal()).ToArray()
                : [];
            return values.Length == 0 ? null : decimal.Round(values.Average(), 4, MidpointRounding.AwayFromZero);
        }
        catch (JsonException) { return null; }
    }

    private static decimal? NormalizeProbability(decimal? value)
    {
        if (value is null || value < 0) return null;
        var normalized = value > 1 ? value / 100m : value;
        return normalized > 1 ? null : decimal.Round(normalized.Value, 4, MidpointRounding.AwayFromZero);
    }

    private static string NormalizeDocumentNumber(string value) =>
        new(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());

    private static bool TryReadDimensions(byte[] bytes, out int width, out int height, out string contentType)
    {
        width = height = 0;
        contentType = "";
        ReadOnlySpan<byte> data = bytes;
        ReadOnlySpan<byte> png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        if (data.Length >= 24 && data[..8].SequenceEqual(png))
        {
            ReadOnlySpan<byte> iend = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44];
            if (data.Length < 36 || !data.Slice(data.Length - 12, 8).SequenceEqual(iend)) return false;
            width = BinaryPrimitives.ReadInt32BigEndian(data.Slice(16, 4));
            height = BinaryPrimitives.ReadInt32BigEndian(data.Slice(20, 4));
            contentType = "image/png";
            return width is > 0 and <= 10000 && height is > 0 and <= 10000;
        }
        if (data.Length < 4 || data[0] != 0xFF || data[1] != 0xD8 ||
            data[^2] != 0xFF || data[^1] != 0xD9) return false;
        var offset = 2;
        while (offset + 8 < data.Length)
        {
            if (data[offset] != 0xFF) { offset++; continue; }
            var marker = data[offset + 1];
            if (marker is 0xD8 or 0xD9) { offset += 2; continue; }
            if (offset + 4 > data.Length) return false;
            var length = BinaryPrimitives.ReadUInt16BigEndian(data.Slice(offset + 2, 2));
            if (length < 2 || offset + 2 + length > data.Length) return false;
            if (marker is 0xC0 or 0xC1 or 0xC2 or 0xC3 or 0xC5 or 0xC6 or 0xC7 or 0xC9 or 0xCA or 0xCB or 0xCD or 0xCE or 0xCF)
            {
                height = BinaryPrimitives.ReadUInt16BigEndian(data.Slice(offset + 5, 2));
                width = BinaryPrimitives.ReadUInt16BigEndian(data.Slice(offset + 7, 2));
                contentType = "image/jpeg";
                return width is > 0 and <= 10000 && height is > 0 and <= 10000;
            }
            offset += 2 + length;
        }
        return false;
    }
}

public sealed record VnptImage(byte[] Bytes, string ContentType);
public sealed record VnptIdentityResult(
    string ReferenceId, string Outcome, decimal? OcrConfidence, decimal? FaceScore,
    bool DocumentNumberExtracted, bool DocumentNumberMatches, bool FaceMatches);

public sealed class VnptEkycException(string code, string message, int status) : Exception(message)
{
    public string Code { get; } = code;
    public int Status { get; } = status;
}
