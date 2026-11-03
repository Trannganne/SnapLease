namespace RentalCamera.Api.Media;

public sealed class MediaStorageOptions
{
    public const string SectionName = "MediaStorage";
    public const string FakeProvider = "Fake";
    public const string CloudinaryProvider = "Cloudinary";

    public string Provider { get; set; } = FakeProvider;
    public bool LiveUploadApproved { get; set; }

    public bool UsesCloudinary =>
        string.Equals(Provider, CloudinaryProvider, StringComparison.OrdinalIgnoreCase);

    public static string? Validate(MediaStorageOptions media, CloudinaryOptions cloudinary)
    {
        if (string.Equals(media.Provider, FakeProvider, StringComparison.OrdinalIgnoreCase))
            return media.LiveUploadApproved
                ? "Không được duyệt upload thật khi kho ảnh đang ở chế độ Fake."
                : null;

        if (!media.UsesCloudinary)
            return "MediaStorage:Provider chỉ chấp nhận Fake hoặc Cloudinary.";
        if (!media.LiveUploadApproved)
            return "Cloudinary chưa được phê duyệt cho môi trường hiện tại.";
        if (!IsSecret(cloudinary.CloudName) || !IsSecret(cloudinary.ApiKey) || !IsSecret(cloudinary.ApiSecret))
            return "Thiếu Cloudinary CloudName, ApiKey hoặc ApiSecret.";
        if (!IsFolder(cloudinary.EvidenceFolder) || !IsFolder(cloudinary.ReviewFolder))
            return "Thư mục Cloudinary không hợp lệ.";
        if (cloudinary.MaximumMegabytes is < 1 or > 20)
            return "Giới hạn ảnh Cloudinary phải từ 1 đến 20 MB.";
        return null;
    }

    private static bool IsSecret(string value) =>
        !string.IsNullOrWhiteSpace(value) &&
        !value.Contains("PLACEHOLDER", StringComparison.OrdinalIgnoreCase) &&
        !value.StartsWith("SET_", StringComparison.OrdinalIgnoreCase);

    private static bool IsFolder(string value) =>
        !string.IsNullOrWhiteSpace(value) && value.Length <= 150 &&
        value.All(c => char.IsLetterOrDigit(c) || c is '-' or '_' or '/');
}
