using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace RentalCamera.Api.Contracts;

public sealed class ContractSignatureService
{
    private readonly string _pepper;

    public ContractSignatureService(IConfiguration configuration)
    {
        var pepper = configuration.GetValue<string>("ElectronicSignature:Pepper");
        if (string.IsNullOrWhiteSpace(pepper))
        {
            throw new InvalidOperationException("Cấu hình ElectronicSignature:Pepper chưa được thiết lập. Vui lòng cung cấp khóa bí mật qua biến môi trường ELECTRONIC_SIGNATURE_PEPPER.");
        }
        _pepper = pepper;
    }

    public string GenerateOtp() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    public (string Hash, string Salt) HashOtp(string otp)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        return (ComputeOtpHash(otp, salt), Convert.ToHexString(salt));
    }

    public bool VerifyOtp(string otp, string expectedHash, string salt)
    {
        byte[] saltBytes;
        byte[] expectedBytes;
        try
        {
            saltBytes = Convert.FromHexString(salt);
            expectedBytes = Convert.FromHexString(expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }

        var actualBytes = Convert.FromHexString(ComputeOtpHash(otp, saltBytes));
        return CryptographicOperations.FixedTimeEquals(actualBytes, expectedBytes);
    }

    public string HashContent(string content) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content)));

    private string ComputeOtpHash(string otp, byte[] salt)
    {
        var otpBytes = Encoding.UTF8.GetBytes(otp);
        var pepperBytes = Encoding.UTF8.GetBytes(_pepper);
        
        var input = new byte[salt.Length + otpBytes.Length + pepperBytes.Length];
        Buffer.BlockCopy(salt, 0, input, 0, salt.Length);
        Buffer.BlockCopy(otpBytes, 0, input, salt.Length, otpBytes.Length);
        Buffer.BlockCopy(pepperBytes, 0, input, salt.Length + otpBytes.Length, pepperBytes.Length);

        // Compute HMAC instead of plain SHA256 for short secrets
        using var hmac = new HMACSHA256(pepperBytes);
        return Convert.ToHexString(hmac.ComputeHash(input));
    }
}
