using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Payments;

public sealed class VnpayService
{
    private readonly VnpayOptions _options;
    private readonly IHttpClientFactory _httpClientFactory;
    private static readonly TimeZoneInfo VietnamTimeZone = ResolveVietnamTimeZone();

    public VnpayService(IOptions<VnpayOptions> options, IHttpClientFactory httpClientFactory)
    {
        _options = options.Value;
        _httpClientFactory = httpClientFactory;
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

    public bool ValidateMerchant(string? tmnCode) =>
        !string.IsNullOrWhiteSpace(tmnCode) &&
        string.Equals(_options.TmnCode, tmnCode, StringComparison.OrdinalIgnoreCase);

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

        if (!string.IsNullOrWhiteSpace(_options.BankCode))
        {
            parameters["vnp_BankCode"] = _options.BankCode;
        }

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

    private static DateTime? ParseVnpayDate(string? value) =>
        DateTime.TryParseExact(value, "yyyyMMddHHmmss", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var result) ? result : null;

    public async Task<VnpayQueryDrResult> QueryTransactionAsync(
        string transactionReference,
        DateTime transactionDate,
        string clientIp,
        CancellationToken ct = default)
    {
        if (!IsConfigured)
            return new VnpayQueryDrResult(false, null, null, "VNPAY chưa được cấu hình.", null, null, null, null, null, "VnpayIsNotConfigured");

        if (string.IsNullOrWhiteSpace(_options.QueryDrUrl) || !Uri.TryCreate(_options.QueryDrUrl, UriKind.Absolute, out _))
            return new VnpayQueryDrResult(false, null, null, "URL QueryDR chưa được cấu hình.", null, null, null, null, null, "QueryDrUrlNotConfigured");

        var requestId = Guid.NewGuid().ToString("N");
        var version = _options.Version;
        var command = "querydr";
        var tmnCode = _options.TmnCode;
        var orderInfo = $"Truy van giao dich {transactionReference}";

        // SQL datetime2 loses DateTime.Kind; attempt timestamps are stored as UTC.
        var vnpTxnDate = TimeZoneInfo.ConvertTimeFromUtc(
            DateTime.SpecifyKind(transactionDate, DateTimeKind.Utc), VietnamTimeZone);
        var txnDateStr = vnpTxnDate.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);

        var nowVn = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, VietnamTimeZone);
        var createDateStr = nowVn.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
        var ipAddr = string.IsNullOrWhiteSpace(clientIp) ? "127.0.0.1" : clientIp;

        var rawHashData = $"{requestId}|{version}|{command}|{tmnCode}|{transactionReference}|{txnDateStr}|{createDateStr}|{ipAddr}|{orderInfo}";
        var secureHash = ComputeHmacSha512(rawHashData, _options.HashSecret);

        var requestBody = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_RequestId"] = requestId,
            ["vnp_Version"] = version,
            ["vnp_Command"] = command,
            ["vnp_TmnCode"] = tmnCode,
            ["vnp_TxnRef"] = transactionReference,
            ["vnp_OrderInfo"] = orderInfo,
            ["vnp_TransactionDate"] = txnDateStr,
            ["vnp_CreateDate"] = createDateStr,
            ["vnp_IpAddr"] = ipAddr,
            ["vnp_SecureHash"] = secureHash
        };

        var client = _httpClientFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(15);
        client.DefaultRequestHeaders.UserAgent.ParseAdd("SnapLease/1.0");

        HttpResponseMessage response;
        string content;
        try
        {
            response = await client.PostAsJsonAsync(_options.QueryDrUrl, requestBody, ct);
            content = await response.Content.ReadAsStringAsync(ct);
        }
        catch (Exception ex)
        {
            return new VnpayQueryDrResult(false, null, null, $"Lỗi kết nối tới VNPAY QueryDR: {ex.Message}", null, null, null, null, null, "ConnectionError");
        }

        if (!response.IsSuccessStatusCode)
        {
            return new VnpayQueryDrResult(false, null, null, $"VNPAY QueryDR trả mã HTTP {response.StatusCode}: {content}", null, null, null, null, content, "HttpError");
        }

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(content);
        }
        catch (JsonException)
        {
            return new VnpayQueryDrResult(false, null, null, "Phản hồi từ VNPAY QueryDR không phải JSON hợp lệ.", null, null, null, null, content, "InvalidJson");
        }

        using (doc)
        {
            var root = doc.RootElement;
            string? GetStr(string prop) => root.TryGetProperty(prop, out var val) && val.ValueKind == JsonValueKind.String ? val.GetString() : null;

            var responseId = GetStr("vnp_ResponseId");
            var resCommand = GetStr("vnp_Command");
            var responseCode = GetStr("vnp_ResponseCode");
            var message = GetStr("vnp_Message");
            var resTmnCode = GetStr("vnp_TmnCode");
            var resTxnRef = GetStr("vnp_TxnRef");
            var resAmountStr = GetStr("vnp_Amount") ?? (root.TryGetProperty("vnp_Amount", out var amtVal) && amtVal.ValueKind == JsonValueKind.Number ? amtVal.GetInt64().ToString() : null);
            var resBankCode = GetStr("vnp_BankCode");
            var resPayDate = GetStr("vnp_PayDate");
            var resTransactionNo = GetStr("vnp_TransactionNo");
            var resTransactionType = GetStr("vnp_TransactionType");
            var transactionStatus = GetStr("vnp_TransactionStatus");
            var resOrderInfo = GetStr("vnp_OrderInfo");
            var resSecureHash = GetStr("vnp_SecureHash");

            // API errors may omit transaction fields. They are never authoritative payment results.
            if (responseCode != "00")
                return new VnpayQueryDrResult(false, responseCode, null,
                    responseCode == "94"
                        ? "VNPAY đang giới hạn truy vấn lặp trong 5 phút. Vui lòng chờ rồi kiểm tra lại; trạng thái thanh toán chưa thay đổi."
                        : "VNPAY chưa trả kết quả giao dịch hợp lệ.",
                    null, null, null, null, null, "QueryDrRejected");

            // Xác thực đối chiếu cơ bản
            if (!string.Equals(resTmnCode, _options.TmnCode, StringComparison.Ordinal))
            {
                return new VnpayQueryDrResult(false, responseCode, transactionStatus, "Mã đơn vị phản hồi không khớp.", null, null, null, null, content, "InvalidMerchant");
            }

            if (!string.Equals(resTxnRef, transactionReference, StringComparison.Ordinal))
            {
                return new VnpayQueryDrResult(false, responseCode, transactionStatus, "Mã tham chiếu phản hồi không khớp.", null, null, null, null, content, "InvalidTxnRef");
            }

            if (string.IsNullOrWhiteSpace(resSecureHash))
                return new VnpayQueryDrResult(false, responseCode, transactionStatus, "Thiếu chữ ký phản hồi QueryDR.", null, null, null, null, null, "MissingSignature");

            // Every authoritative QueryDR response must have a valid signature.
            if (!string.IsNullOrWhiteSpace(resSecureHash))
            {
                var promotionCode = GetStr("vnp_PromotionCode") ?? "";
                var promotionAmount = GetStr("vnp_PromotionAmount") ?? "";
                var expectedData = $"{responseId}|{resCommand}|{responseCode}|{message}|{resTmnCode}|{resTxnRef}|{resAmountStr}|{resBankCode}|{resPayDate}|{resTransactionNo}|{resTransactionType}|{transactionStatus}|{resOrderInfo}|{promotionCode}|{promotionAmount}";
                var expectedHash = ComputeHmacSha512(expectedData, _options.HashSecret);
                if (!string.Equals(resSecureHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                {
                    return new VnpayQueryDrResult(false, responseCode, transactionStatus, "Chữ ký phản hồi từ VNPAY QueryDR không hợp lệ.", null, null, null, null, content, "InvalidSignature");
                }
            }

            long? amountTimes100 = long.TryParse(resAmountStr, NumberStyles.None, CultureInfo.InvariantCulture, out var amt) ? amt : null;
            if (amountTimes100 is null || amountTimes100 <= 0 || resCommand != "querydr" || resTransactionType != "01")
                return new VnpayQueryDrResult(false, responseCode, transactionStatus, "Dữ liệu giao dịch QueryDR không hợp lệ.", null, null, null, null, null, "InvalidTransaction");
            var paidAt = ParseVnpayDate(resPayDate);

            // Giao dịch thành công chỉ khi ResponseCode == "00" VÀ TransactionStatus == "00"
            var isSuccess = responseCode == "00" && transactionStatus == "00";

            return new VnpayQueryDrResult(
                isSuccess,
                responseCode,
                transactionStatus,
                message,
                NullIfEmpty(resTransactionNo),
                NullIfEmpty(resBankCode),
                amountTimes100,
                paidAt,
                content,
                null);
        }
    }

    private static string? NullIfEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? null : value;

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

public sealed record VnpayQueryDrResult(
    bool Success,
    string? ResponseCode,
    string? TransactionStatus,
    string? Message,
    string? TransactionNumber,
    string? BankCode,
    long? AmountTimes100,
    DateTime? PaidAt,
    string? RawResponse,
    string? ErrorDetail);
