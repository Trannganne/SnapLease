namespace RentalCamera.Api.Media;

public sealed class CloudinaryOptions
{
    public string CloudName { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ApiSecret { get; set; } = "";
    public string EvidenceFolder { get; set; } = "rental-camera/bien-ban";
    public string ReviewFolder { get; set; } = "rental-camera/danh-gia";
    public int MaximumMegabytes { get; set; } = 10;
}
