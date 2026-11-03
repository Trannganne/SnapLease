namespace RentalCamera.Api.Identity;

public sealed class VnptEkycOptions
{
    public const string SectionName = "VnptEkyc";
    public const string ApprovedBaseUrl = "https://api.idg.vnpt.vn/";

    public bool Enabled { get; set; }
    public bool LiveApiApproved { get; set; }
    public string BaseUrl { get; set; } = ApprovedBaseUrl;
    public string TokenId { get; set; } = "";
    public string TokenKey { get; set; } = "";
    public string AccessToken { get; set; } = "";
    public string MacAddress { get; set; } = "TEST1";
    public int TimeoutSeconds { get; set; } = 45;
    public decimal FaceMatchThreshold { get; set; } = 0.80m;
}
