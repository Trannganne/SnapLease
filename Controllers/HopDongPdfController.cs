using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace RentalCamera.Controllers;

// Bản in hợp đồng lấy từ API, không truy vấn database MVC và không tạo dữ liệu mẫu.
public class HopDongPdfController : BaseController
{
    protected override string[] GetAllowedRoles() => new[] { "ADMIN", "NHAN_VIEN" };
    private readonly IHttpClientFactory _factory;
    public HopDongPdfController(IHttpClientFactory factory) => _factory = factory;

    [HttpGet]
    public async Task<IActionResult> Index(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Length > 100 || id.Contains('/') || id.Contains('\\'))
            return BadRequest("Mã hợp đồng không hợp lệ.");
        var token = HttpContext.Session.GetString("AccessToken");
        if (string.IsNullOrWhiteSpace(token)) return Unauthorized("Vui lòng đăng nhập lại.");
        try
        {
            using var client = _factory.CreateClient("RentalCameraApi");
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var response = await client.GetAsync($"api/hop-dong/{Uri.EscapeDataString(id)}");
            if (!response.IsSuccessStatusCode)
                return StatusCode((int)response.StatusCode, "Không lấy được hợp đồng từ API. Hãy kiểm tra mã hợp đồng và quyền truy cập.");
            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            ViewBag.ContractId = id;
            return View(doc.RootElement.Clone());
        }
        catch (HttpRequestException) { return StatusCode(503, "Không kết nối được API. Hãy chạy backend trước."); }
        catch (JsonException) { return StatusCode(502, "API trả về dữ liệu hợp đồng không hợp lệ."); }
    }
}
