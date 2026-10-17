using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Media;

public sealed class CloudinaryImageStorage(
    HttpClient httpClient,
    IOptions<CloudinaryOptions> options)
{
    private readonly CloudinaryOptions _options = options.Value;

    public int MaximumBytes => Math.Max(1, _options.MaximumMegabytes) * 1024 * 1024;

    public async Task<CloudinaryUploadResult> UploadEvidenceAsync(
        IFormFile file,
        string contractDetailId,
        CancellationToken ct)
        => await UploadAsync(file, _options.EvidenceFolder, contractDetailId, ct);

    public async Task<CloudinaryUploadResult> UploadReviewImageAsync(
        IFormFile file,
        string reviewId,
        CancellationToken ct)
        => await UploadAsync(file, _options.ReviewFolder, reviewId, ct);

    private async Task<CloudinaryUploadResult> UploadAsync(
        IFormFile file,
        string configuredFolder,
        string ownerId,
        CancellationToken ct)
    {
        EnsureConfigured();

        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
            .ToString(CultureInfo.InvariantCulture);
        var folder = configuredFolder.Trim().Trim('/');
        var publicId = $"{ownerId}-{Guid.NewGuid():N}";
        var signature = Sign(new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["folder"] = folder,
            ["public_id"] = publicId,
            ["timestamp"] = timestamp
        });

        using var form = new MultipartFormDataContent();
        await using var stream = file.OpenReadStream();
        using var fileContent = new StreamContent(stream);
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse(file.ContentType);
        form.Add(fileContent, "file", Path.GetFileName(file.FileName));
        form.Add(new StringContent(_options.ApiKey), "api_key");
        form.Add(new StringContent(timestamp), "timestamp");
        form.Add(new StringContent(folder), "folder");
        form.Add(new StringContent(publicId), "public_id");
        form.Add(new StringContent(signature), "signature");

        var endpoint = $"https://api.cloudinary.com/v1_1/{Uri.EscapeDataString(_options.CloudName)}/image/upload";
        using var response = await httpClient.PostAsync(endpoint, form, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"Cloudinary từ chối ảnh ({(int)response.StatusCode}): {ReadError(body)}");

        using var json = JsonDocument.Parse(body);
        var root = json.RootElement;
        var secureUrl = root.GetProperty("secure_url").GetString();
        var uploadedPublicId = root.GetProperty("public_id").GetString();
        if (string.IsNullOrWhiteSpace(secureUrl) || string.IsNullOrWhiteSpace(uploadedPublicId))
            throw new HttpRequestException("Cloudinary không trả về URL ảnh hợp lệ.");

        return new CloudinaryUploadResult(secureUrl, uploadedPublicId);
    }

    private string Sign(IReadOnlyDictionary<string, string> parameters)
    {
        var value = string.Join('&', parameters.Select(x => $"{x.Key}={x.Value}")) + _options.ApiSecret;
        return Convert.ToHexString(SHA1.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }

    private void EnsureConfigured()
    {
        if (string.IsNullOrWhiteSpace(_options.CloudName)
            || string.IsNullOrWhiteSpace(_options.ApiKey)
            || string.IsNullOrWhiteSpace(_options.ApiSecret))
            throw new InvalidOperationException(
                "Cloudinary chưa được cấu hình. Cần đặt Cloudinary__CloudName, Cloudinary__ApiKey và Cloudinary__ApiSecret.");
    }

    private static string ReadError(string body)
    {
        try
        {
            using var json = JsonDocument.Parse(body);
            return json.RootElement.GetProperty("error").GetProperty("message").GetString()
                ?? "Không có mô tả lỗi.";
        }
        catch (JsonException)
        {
            return "Không đọc được phản hồi lỗi.";
        }
    }
}

public sealed record CloudinaryUploadResult(string SecureUrl, string PublicId);
