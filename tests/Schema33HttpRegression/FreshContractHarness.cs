using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using RentalCamera.Api.Auth;
using RentalCamera.Api.Email;

namespace Schema33HttpRegression;

public static class FreshContractHarness
{
    public static async Task<int> Main(string[] args)
    {
        if (args.Length == 4 && args[0] == "remaining")
            return await RemainingCoverageHarness.RunAsync(args[1], args[2], args[3]);
        if (args.Length == 1 && args[0] == "credentials")
            return await RemainingCoverageHarness.VerifyCredentialsAsync();

        await using var factory = new WebApplicationFactory<global::Program>();
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        using var login = await client.PostAsJsonAsync("/api/auth/login", new
        {
            tenDangNhap = "trial33.customer02",
            matKhau = "TrialOnly!2026a"
        });
        Require(login.StatusCode == HttpStatusCode.OK, "fixture login");
        using var loginJson = JsonDocument.Parse(await login.Content.ReadAsStringAsync());
        var token = loginJson.RootElement.GetProperty("accessToken").GetString();
        Require(!string.IsNullOrWhiteSpace(token), "access token");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var start = new DateTime(2026, 11, 22, 9, 0, 0);
        var end = new DateTime(2026, 11, 22, 17, 0, 0);
        using var addLine = await client.PostAsJsonAsync("/api/gio-hang/chi-tiet", new
        {
            maCuaHang = "TR33_S01", maDongMay = "TR33_M03", soLuong = 1,
            ngayBatDau = start, ngayKetThuc = end, phienBan = (Guid?)null
        });
        Require(addLine.StatusCode == HttpStatusCode.Created, "cart line");
        using var lineJson = JsonDocument.Parse(await addLine.Content.ReadAsStringAsync());
        var lineId = lineJson.RootElement.GetProperty("maChiTietGioHang").GetString();
        var version = lineJson.RootElement.GetProperty("phienBan").GetGuid();
        Require(!string.IsNullOrWhiteSpace(lineId), "cart line id");

        using var checkoutRequest = new HttpRequestMessage(HttpMethod.Post, "/api/gio-hang/checkout")
        {
            Content = JsonContent.Create(new { items = new[] { new { id = lineId, phienBan = version } } })
        };
        checkoutRequest.Headers.Add("Idempotency-Key", "schema33-http-" + Guid.NewGuid().ToString("N"));
        using var checkout = await client.SendAsync(checkoutRequest);
        Require(checkout.StatusCode == HttpStatusCode.Created, "cart checkout");
        using var holdJson = JsonDocument.Parse(await checkout.Content.ReadAsStringAsync());
        var holdId = holdJson.RootElement.GetProperty("maGiuCho").GetString();
        Require(!string.IsNullOrWhiteSpace(holdId), "hold id");

        using var createContract = await client.PostAsync($"/api/giu-cho/{holdId}/xac-nhan-thue", null);
        Require(createContract.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created, "contract creation");
        using var createJson = JsonDocument.Parse(await createContract.Content.ReadAsStringAsync());
        var contractId = createJson.RootElement.GetProperty("maHopDong").GetString();
        Require(!string.IsNullOrWhiteSpace(contractId), "contract id");

        var pdfBytes = Encoding.ASCII.GetBytes("%PDF-1.4\n% Synthetic Schema33 contract fixture; not a legal document.\n%%EOF\n");
        using var pdf = new ByteArrayContent(pdfBytes);
        pdf.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        using var upload = await client.PutAsync($"/api/hop-dong/{contractId}/tep-pdf", pdf);
        Require(upload.StatusCode == HttpStatusCode.OK, "contract PDF upload");

        using var signatureRequest = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/yeu-cau-ky", new
        {
            daDongYDieuKhoan = true
        });
        Require(signatureRequest.StatusCode == HttpStatusCode.Accepted, "signature request");
        using var requestJson = JsonDocument.Parse(await signatureRequest.Content.ReadAsStringAsync());
        var confirmationId = requestJson.RootElement.GetProperty("maXacNhan").GetString();
        Require(!string.IsNullOrWhiteSpace(confirmationId), "signature confirmation id");
        Require(requestJson.RootElement.GetProperty("maOtp").ValueKind == JsonValueKind.Null,
            "OTP must not be exposed through HTTP");

        var mailbox = factory.Services.GetRequiredService<FakeTrialSender>();
        if (!mailbox.TryTake(out var message) || message is null)
            throw new InvalidOperationException("FAIL fake mailbox message");
        Require(message.Purpose == "CONTRACT_OTP:" + contractId, "mailbox purpose binding");
        Require(message.Value.Length == 6 && message.Value.All(char.IsDigit), "mailbox OTP format");

        using var sign = await client.PutAsJsonAsync($"/api/hop-dong/{contractId}/ky", new
        {
            maXacNhan = confirmationId, maOtp = message.Value, daDongYDieuKhoan = true
        });
        Require(sign.StatusCode == HttpStatusCode.OK, "contract signing");
        using var readback = await client.GetAsync($"/api/hop-dong/{contractId}");
        Require(readback.StatusCode == HttpStatusCode.OK, "signed contract readback");
        using var contractJson = JsonDocument.Parse(await readback.Content.ReadAsStringAsync());
        Require(contractJson.RootElement.GetProperty("trangThai").GetString() == "DA_KY", "signed contract status");

        using var staffLogin = await client.PostAsJsonAsync("/api/auth/login", new
        {
            tenDangNhap = "trial33.staff01",
            matKhau = "TrialOnly!2026a"
        });
        Require(staffLogin.StatusCode == HttpStatusCode.OK, "staff fixture login");
        using var staffLoginJson = JsonDocument.Parse(await staffLogin.Content.ReadAsStringAsync());
        var staffToken = staffLoginJson.RootElement.GetProperty("accessToken").GetString();
        Require(!string.IsNullOrWhiteSpace(staffToken), "staff access token");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", staffToken);

        using var readyDevices = await client.GetAsync("/api/thiet-bi?maDongMay=TR33_M03&trangThai=SAN_SANG");
        Require(readyDevices.StatusCode == HttpStatusCode.OK, "ready device lookup");
        using var readyDevicesJson = JsonDocument.Parse(await readyDevices.Content.ReadAsStringAsync());
        var readyDevice = readyDevicesJson.RootElement.EnumerateArray().FirstOrDefault();
        Require(readyDevice.ValueKind == JsonValueKind.Object, "ready device fixture");
        var deviceId = readyDevice.GetProperty("maThietBi").GetString();
        Require(!string.IsNullOrWhiteSpace(deviceId), "ready device id");

        using var prepareDevices = await client.PutAsJsonAsync($"/api/hop-dong/{contractId}/thiet-bi", new
        {
            maThietBi = new[] { deviceId }
        });
        Require(prepareDevices.StatusCode == HttpStatusCode.OK, "prepare physical device");
        using var prepareJson = JsonDocument.Parse(await prepareDevices.Content.ReadAsStringAsync());
        Require(prepareJson.RootElement.GetProperty("trangThai").GetString() == "CHO_BAN_GIAO",
            "prepared contract status");

        using var duplicatePrepare = await client.PutAsJsonAsync($"/api/hop-dong/{contractId}/thiet-bi", new
        {
            maThietBi = new[] { deviceId }
        });
        Require(duplicatePrepare.StatusCode == HttpStatusCode.Conflict,
            "duplicate device preparation guard");

        using var handoverView = await client.GetAsync($"/api/hop-dong/{contractId}/ban-giao");
        Require(handoverView.StatusCode == HttpStatusCode.OK, "handover detail lookup");
        using var handoverViewJson = JsonDocument.Parse(await handoverView.Content.ReadAsStringAsync());
        var contractDetailId = handoverViewJson.RootElement.GetProperty("chiTiet")[0]
            .GetProperty("maChiTietHopDong").GetString();
        Require(!string.IsNullOrWhiteSpace(contractDetailId), "contract detail id");
        var deviceSerial = handoverViewJson.RootElement.GetProperty("chiTiet")[0]
            .GetProperty("soSerial").GetString();
        Require(!string.IsNullOrWhiteSpace(deviceSerial), "contract device serial");

        using var handover = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/ban-giao", new
        {
            thietBi = new[] { new { maChiTietHopDong = contractDetailId, tinhTrang = "Synthetic handover check" } }
        });
        Require(handover.StatusCode == HttpStatusCode.Conflict,
            "handover must be blocked before successful deposit");
        using var handoverJson = JsonDocument.Parse(await handover.Content.ReadAsStringAsync());
        Require(handoverJson.RootElement.GetProperty("loi").GetString() == "Chưa xác nhận thanh toán tiền cọc.",
            "handover deposit blocker message");

        using var malformedHandover = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/ban-giao", new
        {
            thietBi = Array.Empty<object>()
        });
        Require(malformedHandover.StatusCode == HttpStatusCode.BadRequest,
            "empty handover payload guard");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var ownerHandoverView = await client.GetAsync($"/api/hop-dong/{contractId}/ban-giao");
        Require(ownerHandoverView.StatusCode == HttpStatusCode.OK,
            "owner handover detail access");
        using var customerHandoverAttempt = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/ban-giao", new
        {
            thietBi = new[] { new { maChiTietHopDong = contractDetailId, tinhTrang = "Forbidden customer handover" } }
        });
        Require(customerHandoverAttempt.StatusCode == HttpStatusCode.Forbidden,
            "customer cannot perform staff handover");

        using var otherCustomerLogin = await client.PostAsJsonAsync("/api/auth/login", new
        {
            tenDangNhap = "trial33.customer03",
            matKhau = "TrialOnly!2026a"
        });
        Require(otherCustomerLogin.StatusCode == HttpStatusCode.OK, "other customer fixture login");
        using var otherCustomerLoginJson = JsonDocument.Parse(await otherCustomerLogin.Content.ReadAsStringAsync());
        var otherCustomerToken = otherCustomerLoginJson.RootElement.GetProperty("accessToken").GetString();
        Require(!string.IsNullOrWhiteSpace(otherCustomerToken), "other customer access token");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", otherCustomerToken);
        using var otherCustomerView = await client.GetAsync($"/api/hop-dong/{contractId}/ban-giao");
        Require(otherCustomerView.StatusCode == HttpStatusCode.Forbidden,
            "other customer cannot read contract handover");

        var tokenIssuer = factory.Services.GetRequiredService<TokenIssuer>();
        var otherStaffToken = tokenIssuer.Issue("TR33_N02", 0);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", otherStaffToken);
        using var otherStaffView = await client.GetAsync($"/api/hop-dong/{contractId}/ban-giao");
        Require(otherStaffView.StatusCode == HttpStatusCode.Forbidden,
            "other branch staff cannot read contract handover");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", staffToken);

        using var receive = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/nhan-lai", new
        {
            operationId = "schema33-return-" + Guid.NewGuid().ToString("N"),
            thietBi = new[]
            {
                new
                {
                    maChiTietHopDong = contractDetailId, tinhTrang = "Synthetic return check",
                    coHuHong = false, soSerialDoiChieu = deviceSerial
                }
            }
        });
        Require(receive.StatusCode == HttpStatusCode.Conflict,
            "return must be blocked before active rental");
        using var receiveJson = JsonDocument.Parse(await receive.Content.ReadAsStringAsync());
        Require(receiveJson.RootElement.GetProperty("loi").GetString() == "Hợp đồng không ở trạng thái đang thuê.",
            "return state blocker message");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var extensionDate = end.AddDays(1).ToString("O");
        using var extensionQuote = await client.GetAsync(
            $"/api/hop-dong/{contractId}/du-kien-gia-han?thoiHanTraMoi={Uri.EscapeDataString(extensionDate)}");
        Require(extensionQuote.StatusCode == HttpStatusCode.Conflict,
            "extension must be blocked before active rental");
        using var extensionJson = JsonDocument.Parse(await extensionQuote.Content.ReadAsStringAsync());
        Require(!extensionJson.RootElement.GetProperty("coTheGiaHan").GetBoolean(),
            "extension quote rejection");

        using var createDeposit = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/thanh-toan-coc", new
        {
            phuongThuc = "TIEN_MAT",
            noiDungChuyenKhoan = (string?)null
        });
        Require(createDeposit.StatusCode == HttpStatusCode.Created, "cash deposit creation");
        using var createDepositJson = JsonDocument.Parse(await createDeposit.Content.ReadAsStringAsync());
        var paymentId = createDepositJson.RootElement.GetProperty("maThanhToan").GetString();
        Require(!string.IsNullOrWhiteSpace(paymentId), "deposit payment id");
        Require(createDepositJson.RootElement.GetProperty("trangThai").GetString() == "CHO_THANH_TOAN",
            "deposit pending status");

        using var duplicateDeposit = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/thanh-toan-coc", new
        {
            phuongThuc = "TIEN_MAT",
            noiDungChuyenKhoan = (string?)null
        });
        Require(duplicateDeposit.StatusCode == HttpStatusCode.Conflict,
            "duplicate deposit guard");
        using var customerConfirmDeposit = await client.PostAsJsonAsync($"/api/thanh-toan/{paymentId}/xac-nhan", new
        {
            thanhCong = true,
            maGiaoDich = (string?)null
        });
        Require(customerConfirmDeposit.StatusCode == HttpStatusCode.Forbidden,
            "customer cannot confirm deposit");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", staffToken);
        using var confirmDeposit = await client.PostAsJsonAsync($"/api/thanh-toan/{paymentId}/xac-nhan", new
        {
            thanhCong = true,
            maGiaoDich = (string?)null
        });
        Require(confirmDeposit.StatusCode == HttpStatusCode.OK, "staff deposit confirmation");
        using var confirmDepositJson = JsonDocument.Parse(await confirmDeposit.Content.ReadAsStringAsync());
        Require(confirmDepositJson.RootElement.GetProperty("trangThai").GetString() == "THANH_CONG",
            "deposit success status");

        using var repeatDepositConfirmation = await client.PostAsJsonAsync($"/api/thanh-toan/{paymentId}/xac-nhan", new
        {
            thanhCong = true,
            maGiaoDich = (string?)null
        });
        Require(repeatDepositConfirmation.StatusCode == HttpStatusCode.Conflict,
            "repeat deposit confirmation guard");

        using var completeHandover = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/ban-giao", new
        {
            thietBi = new[] { new { maChiTietHopDong = contractDetailId, tinhTrang = "Synthetic handover good" } }
        });
        Require(completeHandover.StatusCode == HttpStatusCode.OK, "paid contract handover");
        using var completeHandoverJson = JsonDocument.Parse(await completeHandover.Content.ReadAsStringAsync());
        Require(completeHandoverJson.RootElement.GetProperty("trangThai").GetString() == "DANG_THUE",
            "active rental status");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var activeExtensionQuote = await client.GetAsync(
            $"/api/hop-dong/{contractId}/du-kien-gia-han?thoiHanTraMoi={Uri.EscapeDataString(extensionDate)}");
        Require(activeExtensionQuote.StatusCode == HttpStatusCode.OK, "active rental extension quote");
        using var activeExtensionQuoteJson = JsonDocument.Parse(await activeExtensionQuote.Content.ReadAsStringAsync());
        Require(activeExtensionQuoteJson.RootElement.GetProperty("coTheGiaHan").GetBoolean(),
            "active extension allowed");

        using var createExtension = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/yeu-cau-gia-han", new
        {
            thoiHanTraMoi = end.AddDays(1),
            lyDoGiaHan = "Synthetic Schema33 extension test",
            ghiChu = "Trial only"
        });
        Require(createExtension.StatusCode == HttpStatusCode.Created, "extension request creation");
        using var createExtensionJson = JsonDocument.Parse(await createExtension.Content.ReadAsStringAsync());
        var extensionId = createExtensionJson.RootElement.GetProperty("maPhuLuc").GetString();
        Require(!string.IsNullOrWhiteSpace(extensionId), "extension id");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", staffToken);
        using var approveExtension = await client.PutAsJsonAsync($"/api/gia-han/{extensionId}/xu-ly", new
        {
            quyetDinh = "DUYET",
            ghiChu = "Synthetic approval"
        });
        Require(approveExtension.StatusCode == HttpStatusCode.OK, "extension approval");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var appendixPdf = new ByteArrayContent(Encoding.ASCII.GetBytes(
            "%PDF-1.4\n% Synthetic Schema33 appendix fixture; not a legal document.\n%%EOF\n"));
        appendixPdf.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        using var uploadAppendix = await client.PutAsync($"/api/gia-han/{extensionId}/tep-pdf", appendixPdf);
        Require(uploadAppendix.StatusCode == HttpStatusCode.OK, "appendix PDF upload");

        using var requestAppendixSignature = await client.PostAsync($"/api/gia-han/{extensionId}/yeu-cau-ky", null);
        Require(requestAppendixSignature.StatusCode == HttpStatusCode.OK, "appendix signature request");
        using var requestAppendixJson = JsonDocument.Parse(await requestAppendixSignature.Content.ReadAsStringAsync());
        var appendixConfirmationId = requestAppendixJson.RootElement.GetProperty("maXacNhan").GetString();
        var appendixContentHash = requestAppendixJson.RootElement.GetProperty("maBamNoiDung").GetString();
        Require(!string.IsNullOrWhiteSpace(appendixConfirmationId), "appendix confirmation id");
        Require(!string.IsNullOrWhiteSpace(appendixContentHash), "appendix content hash");
        if (!mailbox.TryTake(out var appendixMessage) || appendixMessage is null)
            throw new InvalidOperationException("FAIL fake appendix mailbox message");
        Require(appendixMessage.Purpose == "CONTRACT_OTP:phụ lục " + extensionId,
            "appendix mailbox purpose binding");

        using var signAppendix = await client.PutAsJsonAsync($"/api/gia-han/{extensionId}/ky", new
        {
            maXacNhan = appendixConfirmationId,
            maOtp = appendixMessage.Value,
            maBamNoiDung = appendixContentHash,
            daDongYDieuKhoan = true
        });
        Require(signAppendix.StatusCode == HttpStatusCode.OK, "appendix signing");
        using var signAppendixJson = JsonDocument.Parse(await signAppendix.Content.ReadAsStringAsync());
        Require(signAppendixJson.RootElement.GetProperty("trangThai").GetString() == "DA_HIEU_LUC",
            "effective extension status");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", staffToken);
        using var completeReturn = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/nhan-lai", new
        {
            operationId = "schema33-return-positive-" + Guid.NewGuid().ToString("N"),
            thietBi = new[]
            {
                new
                {
                    maChiTietHopDong = contractDetailId, tinhTrang = "Synthetic returned good",
                    coHuHong = false, soSerialDoiChieu = deviceSerial
                }
            }
        });
        Require(completeReturn.StatusCode == HttpStatusCode.OK, "full return receipt");

        using var inspectReturn = await client.PutAsJsonAsync($"/api/hop-dong/{contractId}/nhan-lai/kiem-tra", new
        {
            operationId = "schema33-inspect-" + Guid.NewGuid().ToString("N"),
            kiemTraLucUtcDaXem = (DateTime?)null,
            thietBi = new[]
            {
                new
                {
                    maChiTietHopDong = contractDetailId, tinhTrang = "Synthetic returned good",
                    coHuHong = false, thieuPhuKien = false, ketQua = "DAT",
                    tinhTrangPhuKien = (string?)null
                }
            }
        });
        Require(inspectReturn.StatusCode == HttpStatusCode.OK, "return inspection");

        using var finalizeSettlement = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/quyet-toan/chot", new
        {
            operationId = "schema33-settlement-" + Guid.NewGuid().ToString("N"),
            maBamQuyetToan = (string?)null
        });
        Require(finalizeSettlement.StatusCode == HttpStatusCode.OK, "settlement finalization");

        using var settlementView = await client.GetAsync($"/api/hop-dong/{contractId}/quyet-toan");
        Require(settlementView.StatusCode == HttpStatusCode.OK, "settlement view");
        using var settlementJson = JsonDocument.Parse(await settlementView.Content.ReadAsStringAsync());
        Require(settlementJson.RootElement.GetProperty("trangThaiQuyetToan").GetString() == "DA_CHOT",
            "settlement finalized status");
        var settlementHash = settlementJson.RootElement.GetProperty("maBamQuyetToan").GetString();
        var refundable = settlementJson.RootElement.GetProperty("conPhaiHoan").GetDecimal();
        Require(!string.IsNullOrWhiteSpace(settlementHash), "settlement hash");
        Require(refundable > 0, "deposit refund expected");

        using var createRefund = await client.PostAsJsonAsync($"/api/hop-dong/{contractId}/hoan-coc", new
        {
            operationId = "schema33-refund-create-" + Guid.NewGuid().ToString("N"),
            maBamQuyetToan = settlementHash,
            phuongThuc = "TIEN_MAT",
            loaiThanhToan = "HOAN_COC"
        });
        Require(createRefund.StatusCode == HttpStatusCode.OK, "deposit refund creation");
        using var createRefundJson = JsonDocument.Parse(await createRefund.Content.ReadAsStringAsync());
        var refundId = createRefundJson.RootElement.GetProperty("maThanhToan").GetString();
        Require(!string.IsNullOrWhiteSpace(refundId), "refund payment id");

        using var confirmRefund = await client.PutAsJsonAsync($"/api/thanh-toan/{refundId}/xac-nhan-hoan", new
        {
            operationId = "schema33-refund-staff-" + Guid.NewGuid().ToString("N")
        });
        Require(confirmRefund.StatusCode == HttpStatusCode.OK, "staff refund confirmation");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var refundView = await client.GetAsync($"/api/hop-dong/{contractId}/khoan-hoan");
        Require(refundView.StatusCode == HttpStatusCode.OK, "refund view");
        using var refundViewJson = JsonDocument.Parse(await refundView.Content.ReadAsStringAsync());
        var refundRow = refundViewJson.RootElement.EnumerateArray()
            .Single(x => x.GetProperty("maThanhToan").GetString() == refundId);
        var refundHash = refundRow.GetProperty("maBamKhoanHoan").GetString();
        var refundAmount = refundRow.GetProperty("soTien").GetDecimal();
        Require(refundAmount == refundable, "refund amount matches settlement");

        using var acknowledgeRefund = await client.PostAsJsonAsync($"/api/thanh-toan/{refundId}/xac-nhan-nhan-hoan", new
        {
            operationId = "schema33-refund-owner-" + Guid.NewGuid().ToString("N"),
            soTienXacNhan = refundAmount,
            maBamKhoanHoan = refundHash
        });
        Require(acknowledgeRefund.StatusCode == HttpStatusCode.OK, "customer refund acknowledgement");

        using var completedContract = await client.GetAsync($"/api/hop-dong/{contractId}");
        Require(completedContract.StatusCode == HttpStatusCode.OK, "completed contract readback");
        using var completedContractJson = JsonDocument.Parse(await completedContract.Content.ReadAsStringAsync());
        Require(completedContractJson.RootElement.GetProperty("trangThai").GetString() == "HOAN_THANH",
            "completed contract status");

        Console.WriteLine($"PASS full Schema33 lifecycle: contract, DI-only OTP, cash deposit, handover, extension approval/signing, return/inspection, settlement and acknowledged refund; contract={contractId}; OTP not printed; fake trial only.");
        return 0;
    }

    private static void Require(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException("FAIL " + name);
    }
}
