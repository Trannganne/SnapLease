using System.Net.Http.Headers;
using Microsoft.AspNetCore.Mvc;

namespace RentalCamera.Controllers;

[Route("ThongBao")]
public class ThongBaoController : Controller
{
    private readonly IHttpClientFactory _clients;

    public ThongBaoController(IHttpClientFactory clients)
    {
        _clients = clients;
    }

    private HttpClient? CreateApiClient()
    {
        var token = HttpContext.Session.GetString("AccessToken");

        if (string.IsNullOrWhiteSpace(token))
            return null;

        var client = _clients.CreateClient("RentalCameraApi");

        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        return client;
    }

    [HttpGet("DanhSach")]
    public async Task<IActionResult> DanhSach(
        int trang = 1,
        int kichThuocTrang = 10)
    {
        var client = CreateApiClient();

        if (client == null)
            return Unauthorized();

        try
        {
            var url = $"api/thong-bao?trang={trang}&kichThuocTrang={kichThuocTrang}";

            using var response = await client.GetAsync(url);

            if (!response.IsSuccessStatusCode)
                return StatusCode((int)response.StatusCode);

            var json = await response.Content.ReadAsStringAsync();

            return Content(json, "application/json");
        }
        catch (HttpRequestException)
        {
            return StatusCode(502, "Không thể kết nối Backend.");
        }
    }

    [HttpPut("DanhDauDaDoc/{id}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DanhDauDaDoc(string id)
    {
        var client = CreateApiClient();

        if (client == null)
            return Unauthorized();

        try
        {
            using var response = await client.PutAsync(
                $"api/thong-bao/{Uri.EscapeDataString(id)}/da-doc",
                null
            );

            return StatusCode((int)response.StatusCode);
        }
        catch (HttpRequestException)
        {
            return StatusCode(502);
        }
    }
}