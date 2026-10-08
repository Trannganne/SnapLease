using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Payments;

public sealed class VnpayService
{
    private readonly VnpayOptions _options;
    private static readonly TimeZoneInfo VietnamTimeZone = ResolveVietnamTimeZone();

    public VnpayService(IOptions<VnpayOptions> options)
    {
        _options = options.Value;
    }

    public bool IsConfigured =>
        _options.Enabled &&
        !string.IsNullOrWhiteSpace(_options.TmnCode) &&
        !string.IsNullOrWhiteSpace(_options.HashSecret) &&
        Uri.TryCreate(_options.PaymentUrl, UriKind.Absolute, out _) &&
        Uri.TryCreate(_options.ReturnUrl, UriKind.Absolute, out _);

    public string? MobileCallbackUrl =>
        Uri.TryCreate(_options.MobileCallbackUrl, UriKind.Absolute, out var uri)
            ? uri.ToString()
            : null;

    public VnpayPaymentLink CreatePaymentUrl(
        string transactionReference,
        decimal amount,
        string orderInfo,
        string ipAddress)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("VNPAY Sandbox chưa được cấu hình đầy đủ.");
        if (amount <= 0)
            throw new ArgumentOutOfRangeException(nameof(amount), "Số tiền thanh toán phải lớn hơn 0.");

        var createdAtUtc = DateTime.UtcNow;
        var expiresAtUtc = createdAtUtc.AddMinutes(Math.Clamp(_options.ExpirationMinutes, 5, 60));
        var createdAt = TimeZoneInfo.ConvertTimeFromUtc(createdAtUtc, VietnamTimeZone);
        var expiresAt = TimeZoneInfo.ConvertTimeFromUtc(expiresAtUtc, VietnamTimeZone);
        var amountTimes100 = checked(decimal.ToInt64(amount * 100m));
        var parameters = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Version"] = _options.Version,
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = _options.TmnCode,
            ["vnp_Amount"] = amountTimes100.ToString(CultureInfo.InvariantCulture),
            ["vnp_BankCode"] = "VNPAYQR",
            ["vnp_CreateDate"] = createdAt.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_CurrCode"] = "VND",
            ["vnp_IpAddr"] = string.IsNullOrWhiteSpace(ipAddress) ? "127.0.0.1" : ipAddress,
            ["vnp_Locale"] = "vn",
            ["vnp_OrderInfo"] = orderInfo,
            ["vnp_OrderType"] = _options.OrderType,
            ["vnp_ReturnUrl"] = _options.ReturnUrl,
            ["vnp_ExpireDate"] = expiresAt.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_TxnRef"] = transactionReference
        };

        var query = BuildQuery(parameters);
        var signature = ComputeHmacSha512(query, _options.HashSecret);
        var paymentUrl = $"{_options.PaymentUrl.TrimEnd('?')}?{query}&vnp_SecureHash={signature}";
        return new VnpayPaymentLink(paymentUrl, createdAtUtc, expiresAtUtc, transactionReference);
    }

    public bool ValidateSignature(IQueryCollection query)
    {
        var receivedSignature = query["vnp_SecureHash"].ToString();
        if (string.IsNullOrWhiteSpace(receivedSignature)) return false;

        var parameters = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (var item in query)
        {
            if (!item.Key.StartsWith("vnp_", StringComparison.Ordinal) ||
                item.Key.Equals("vnp_SecureHash", StringComparison.OrdinalIgnoreCase) ||
                item.Key.Equals("vnp_SecureHashType", StringComparison.OrdinalIgnoreCase))
                continue;

            var value = item.Value.ToString();
            if (!string.IsNullOrEmpty(value)) parameters[item.Key] = value;
        }

        var calculatedSignature = ComputeHmacSha512(BuildQuery(parameters), _options.HashSecret);
        try
        {
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(calculatedSignature),
                Convert.FromHexString(receivedSignature));
        }
        catch (FormatException)
        {
            return false;
        }
    }

    public static bool TryReadCallback(IQueryCollection query, out VnpayCallbackData? callback)
    {
        callback = null;
        var transactionReference = query["vnp_TxnRef"].ToString();
        var responseCode = query["vnp_ResponseCode"].ToString();
        var transactionStatus = query["vnp_TransactionStatus"].ToString();
        if (string.IsNullOrWhiteSpace(transactionReference) ||
            string.IsNullOrWhiteSpace(responseCode) ||
            string.IsNullOrWhiteSpace(transactionStatus) ||
            !long.TryParse(query["vnp_Amount"].ToString(), NumberStyles.None, CultureInfo.InvariantCulture, out var amountTimes100))
            return false;

        callback = new VnpayCallbackData(
            transactionReference,
            amountTimes100,
            responseCode,
            transactionStatus,
            NullIfEmpty(query["vnp_TransactionNo"].ToString()),
            NullIfEmpty(query["vnp_BankCode"].ToString()),
            NullIfEmpty(query["vnp_CardType"].ToString()),
            ParseVnpayDate(query["vnp_PayDate"].ToString()));
        return true;
    }

    private static string BuildQuery(IEnumerable<KeyValuePair<string, string>> parameters) =>
        string.Join("&", parameters.Select(item => $"{WebUtility.UrlEncode(item.Key)}={WebUtility.UrlEncode(item.Value)}"));

    private static string ComputeHmacSha512(string data, string secret)
    {
        using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(data))).ToLowerInvariant();
    }

    private static DateTime? ParseVnpayDate(string value) =>
        DateTime.TryParseExact(value, "yyyyMMddHHmmss", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var result) ? result : null;

    private static string? NullIfEmpty(string value) => string.IsNullOrWhiteSpace(value) ? null : value;

    private static TimeZoneInfo ResolveVietnamTimeZone()
    {
        foreach (var id in new[] { "Asia/Ho_Chi_Minh", "SE Asia Standard Time" })
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
            catch (TimeZoneNotFoundException) { }
            catch (InvalidTimeZoneException) { }
        }
        return TimeZoneInfo.CreateCustomTimeZone("UTC+07", TimeSpan.FromHours(7), "UTC+07", "UTC+07");
    }
}

public sealed record VnpayPaymentLink(
    string PaymentUrl,
    DateTime CreatedAtUtc,
    DateTime ExpiresAtUtc,
    string TransactionReference);

public sealed record VnpayCallbackData(
    string TransactionReference,
    long AmountTimes100,
    string ResponseCode,
    string TransactionStatus,
    string? TransactionNumber,
    string? BankCode,
    string? CardType,
    DateTime? PaidAt);
