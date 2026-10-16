using Microsoft.AspNetCore.Mvc;
namespace RentalCamera.Controllers;
public abstract class BaseController:Controller { public override void OnActionExecuting(Microsoft.AspNetCore.Mvc.Filters.ActionExecutingContext c){ if(HttpContext.Session.GetString("User")==null){ c.Result=RedirectToAction("Login","Auth"); return;} ViewBag.User=HttpContext.Session.GetString("User"); ViewBag.Role=HttpContext.Session.GetString("Role"); base.OnActionExecuting(c);} }
