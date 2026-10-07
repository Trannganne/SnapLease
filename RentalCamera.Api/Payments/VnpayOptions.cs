namespace RentalCamera.Api.Payments;

public sealed class VnpayOptions
{
    public bool Enabled { get; set; }
    public string TmnCode { get; set; } = "";
    public string HashSecret { get; set; } = "";
    public string PaymentUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
    public string ReturnUrl { get; set; } = "";
    public string IpnUrl { get; set; } = "";
    public string MobileCallbackUrl { get; set; } = "";
    public string Version { get; set; } = "2.1.0";
    public string OrderType { get; set; } = "other";
    public int ExpirationMinutes { get; set; } = 15;
}
