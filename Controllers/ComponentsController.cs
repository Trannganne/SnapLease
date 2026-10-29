using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;

namespace RentalCamera.Controllers;

// Component catalogue is intentionally inaccessible outside Development.
public sealed class ComponentsController : Controller
{
    private readonly IWebHostEnvironment _environment;
    public ComponentsController(IWebHostEnvironment environment) => _environment = environment;
    [HttpGet("/components")]
    public IActionResult Index() => _environment.IsDevelopment() ? View() : NotFound();
}
