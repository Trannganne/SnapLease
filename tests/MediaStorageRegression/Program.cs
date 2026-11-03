using System.Net;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Media;

void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine("PASS " + name);
}

var fake = new MediaStorageOptions();
var emptyCloudinary = new CloudinaryOptions();
Check(MediaStorageOptions.Validate(fake, emptyCloudinary) is null,
    "fake storage works without external credentials");

var live = new MediaStorageOptions { Provider = "cloudinary", LiveUploadApproved = false };
Check(MediaStorageOptions.Validate(live, emptyCloudinary)?.Contains("phê duyệt") == true,
    "live upload requires explicit approval");

live.LiveUploadApproved = true;
Check(MediaStorageOptions.Validate(live, emptyCloudinary)?.Contains("Thiếu Cloudinary") == true,
    "live upload requires all Cloudinary credentials");

var cloudinary = new CloudinaryOptions
{
    CloudName = "demo-cloud",
    ApiKey = "test-api-key",
    ApiSecret = "test-api-secret",
    EvidenceFolder = "rental-camera/bien-ban",
    ReviewFolder = "rental-camera/danh-gia",
    MaximumMegabytes = 10
};
Check(MediaStorageOptions.Validate(live, cloudinary) is null,
    "approved complete Cloudinary configuration is accepted");

var handler = new CloudinaryHandler();
var storage = new CloudinaryImageStorage(
    new HttpClient(handler), Options.Create(cloudinary), Options.Create(live));
var bytes = Encoding.UTF8.GetBytes("not-a-real-image-but-valid-upload-payload");
await using var stream = new MemoryStream(bytes);
var formFile = new FormFile(stream, 0, bytes.Length, "anh", "ban-giao.jpg")
{
    Headers = new HeaderDictionary(),
    ContentType = "image/jpeg"
};
var result = await storage.UploadEvidenceAsync(formFile, "CTHD001", CancellationToken.None);

Check(result.SecureUrl == "https://res.cloudinary.com/demo/image/upload/bien-ban.jpg",
    "provider secure URL is returned for database persistence");
Check(result.PublicId == "rental-camera/bien-ban/CTHD001-test",
    "provider public ID is retained for cleanup");
Check(handler.RequestUri?.Host == "api.cloudinary.com" &&
      handler.RequestUri.AbsolutePath == "/v1_1/demo-cloud/image/upload",
    "upload targets only the approved Cloudinary endpoint");
Check(handler.HasApiKey && handler.HasSignature && handler.HasEvidenceFolder,
    "signed upload includes required fields and evidence folder");

Console.WriteLine("PASS media storage regression; no live provider call was made.");

sealed class CloudinaryHandler : HttpMessageHandler
{
    public Uri? RequestUri { get; private set; }
    public bool HasApiKey { get; private set; }
    public bool HasSignature { get; private set; }
    public bool HasEvidenceFolder { get; private set; }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        RequestUri = request.RequestUri;
        if (request.Content is MultipartFormDataContent multipart)
        {
            foreach (var part in multipart)
            {
                var name = part.Headers.ContentDisposition?.Name?.Trim('"');
                if (name == "signature") HasSignature = true;
                if (name == "api_key")
                    HasApiKey = await part.ReadAsStringAsync(cancellationToken) == "test-api-key";
                if (name == "folder")
                    HasEvidenceFolder = await part.ReadAsStringAsync(cancellationToken) == "rental-camera/bien-ban";
            }
        }
        var json = """
            {"secure_url":"https://res.cloudinary.com/demo/image/upload/bien-ban.jpg","public_id":"rental-camera/bien-ban/CTHD001-test"}
            """;
        return new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
    }
}
