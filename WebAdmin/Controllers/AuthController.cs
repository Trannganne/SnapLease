using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc;
namespace RentalCamera.Controllers;
public class AuthController:Controller {
 private readonly IHttpClientFactory _clients; public AuthController(IHttpClientFactory clients)=>_clients=clients;
 [HttpGet] public IActionResult Login()=>View();
 [HttpPost] public async Task<IActionResult> Login(string username,string password,bool remember=false){
  if(string.IsNullOrWhiteSpace(username)||string.IsNullOrWhiteSpace(password)){ViewBag.Error="Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.";return View();}
  try{
   var client=_clients.CreateClient("RentalCameraApi");
   var res=await client.PostAsJsonAsync("api/auth/login",new{tenDangNhap=username.Trim(),matKhau=password});
   if(!res.IsSuccessStatusCode){ViewBag.Error=res.StatusCode==System.Net.HttpStatusCode.Unauthorized?"Tên đăng nhập hoặc mật khẩu không đúng.":"Đăng nhập thất bại. Vui lòng kiểm tra thông tin.";return View();}
   var data=await res.Content.ReadFromJsonAsync<LoginResponse>(); if(data is null||string.IsNullOrWhiteSpace(data.AccessToken)){ViewBag.Error="Backend không trả về token hợp lệ.";return View();}
   HttpContext.Session.SetString("User",data.TenDangNhap??username); HttpContext.Session.SetString("Role",data.VaiTro??""); HttpContext.Session.SetString("AccountId",data.MaTaiKhoan??""); HttpContext.Session.SetString("AccessToken",data.AccessToken);
   return RedirectToAction("Index","Home");
  }catch(HttpRequestException){ViewBag.Error="Không thể kết nối Backend API. Hãy kiểm tra Docker và http://localhost:5000/api/health.";return View();}
 }
 public IActionResult Logout(){HttpContext.Session.Clear();return RedirectToAction("Login");}
 private sealed class LoginResponse{public string AccessToken{get;set;}="";public string? TokenType{get;set;}public int ExpiresInSeconds{get;set;}public string? MaTaiKhoan{get;set;}public string? TenDangNhap{get;set;}public string? VaiTro{get;set;}}
}
