using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;

var builder = WebApplication.CreateBuilder(args);

// MVC
builder.Services.AddControllersWithViews();

// API
builder.Services.AddHttpClient(
    "RentalCameraApi",
    client =>
    {
        client.BaseAddress = new Uri(
            builder.Configuration["ApiSettings:BaseUrl"]
            ?? "http://localhost:5000/"
        );
    }
);

// Database
builder.Services.AddDbContext<RentalCameraDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("RentalCameraConnection")
    )
);

// Session
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromHours(2);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

var app = builder.Build();

// Xử lý lỗi
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// HTTPS
app.UseHttpsRedirection();

// QUAN TRỌNG:
// Cho phép sử dụng CSS, JavaScript, hình ảnh trong wwwroot
app.UseStaticFiles();

// Routing
app.UseRouting();

// Session
app.UseSession();

// Route mặc định
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Auth}/{action=Login}/{id?}"
);

app.Run();