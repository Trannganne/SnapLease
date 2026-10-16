using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace RentalCamera.Controllers;

public class SnapLeaseController : Controller
{
    private readonly IHttpClientFactory _factory;
    public SnapLeaseController(IHttpClientFactory factory) => _factory = factory;
    private HttpClient Client()
    {
        var c = _factory.CreateClient("RentalCameraApi");
        var token = HttpContext.Session.GetString("AccessToken");
        if (!string.IsNullOrWhiteSpace(token)) c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return c;
    }
    public IActionResult Index() => View();
    public IActionResult TienCoc() => RedirectToAction(nameof(Index), new { tab = "tiencoc" });
    public IActionResult PhanBo() => RedirectToAction(nameof(Index), new { tab = "phanbo" });
    public IActionResult HopDong() => RedirectToAction(nameof(Index), new { tab = "hopdong" });
    public IActionResult HinhAnh() => RedirectToAction(nameof(Index), new { tab = "hinhanh" });

    [HttpGet]
    public async Task<IActionResult> Fetch(string path)
    {
        if (string.IsNullOrEmpty(HttpContext.Session.GetString("AccessToken"))) return Unauthorized(new {loi="Phiên đăng nhập đã hết hạn."});
        if (!Allowed(path, false)) return BadRequest(new {loi="Đường dẫn API không hợp lệ"});
        try { using var response = await Client().GetAsync(path); return new ContentResult { Content = await response.Content.ReadAsStringAsync(), ContentType = "application/json; charset=utf-8", StatusCode = (int)response.StatusCode }; }
        catch (HttpRequestException) { return StatusCode(503, new {loi="Không kết nối được SnapLease API tại localhost:5000"}); }
    }
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Send(string path, string method, string payload)
    {
        if (string.IsNullOrEmpty(HttpContext.Session.GetString("AccessToken"))) return Unauthorized(new {loi="Phiên đăng nhập đã hết hạn."});
        if (!Allowed(path, true) || method is not ("POST" or "PUT")) return BadRequest(new {loi="Yêu cầu không hợp lệ"});
        try
        {
            using var doc = JsonDocument.Parse(payload);
            using var req = new HttpRequestMessage(method == "PUT" ? HttpMethod.Put : HttpMethod.Post, path);
            req.Content = JsonContent.Create(doc.RootElement);
            using var response = await Client().SendAsync(req);
            return new ContentResult { Content = await response.Content.ReadAsStringAsync(), ContentType = "application/json; charset=utf-8", StatusCode = (int)response.StatusCode };
        }
        catch (JsonException) { return BadRequest(new {loi="JSON không hợp lệ"}); }
        catch (HttpRequestException) { return StatusCode(503, new {loi="Không kết nối được SnapLease API"}); }
    }
    private static bool Allowed(string path, bool write)
    {
        if (!SafePath(path)) return false;
        var parts = path.Split('/');
        if (!write) return path == "api/thiet-bi" ||
            (parts.Length == 3 && parts[0] == "api" && parts[1] == "hop-dong") ||
            (parts.Length == 4 && parts[0] == "api" && parts[1] == "hop-dong" && parts[3] is "thanh-toan" or "ban-giao" or "quyet-toan");
        return (parts.Length == 4 && parts[0] == "api" && parts[1] == "hop-dong" && parts[3] is "thiet-bi" or "ban-giao" or "nhan-lai" or "hoan-coc") ||
            (parts.Length == 4 && parts[0] == "api" && parts[1] == "thanh-toan" && parts[3] is "xac-nhan" or "xac-nhan-hoan") ||
            (parts.Length == 4 && parts[0] == "api" && parts[1] == "chi-tiet-hop-dong" && parts[3] == "anh-bien-ban");
    }
    private static bool SafePath(string s) => !string.IsNullOrWhiteSpace(s) && s.Length < 400 && !s.Contains(":") && !s.Contains("//") && !s.Contains("..") && !s.Contains('\\') && !s.StartsWith('/');
}
public sealed record WorkspaceVm(string Title, string Description, string Mode);
