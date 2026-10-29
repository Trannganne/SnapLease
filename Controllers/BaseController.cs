using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace RentalCamera.Controllers;

public abstract class BaseController : Controller
{
    public override void OnActionExecuting(
        ActionExecutingContext context)
    {
        var user = HttpContext.Session.GetString("User");
        var role = HttpContext.Session.GetString("Role");

        // Chưa đăng nhập
        if (string.IsNullOrEmpty(user))
        {
            context.Result = RedirectToAction(
                "Login", "Auth");
            return;
        }

        // Kiểm tra vai trò
        var allowedRoles = GetAllowedRoles();

        if (allowedRoles.Length > 0 &&
            !allowedRoles.Contains(role))
        {
            context.Result = StatusCode(
                403,
                "Bạn không có quyền truy cập chức năng này.");
            return;
        }

        ViewBag.User = user;
        ViewBag.Role = role;

        base.OnActionExecuting(context);
    }

    protected virtual string[] GetAllowedRoles()
    {
        return Array.Empty<string>();
    }
}