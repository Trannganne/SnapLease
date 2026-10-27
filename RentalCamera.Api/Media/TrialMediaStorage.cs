using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Reviews;
using System.Security.Claims;

namespace RentalCamera.Api.Media;

// Files remain files, while AnhBienBan/AnhDanhGia retain their relational ownership.
public static class TrialMediaStorage
{
    private static string Root => Path.Combine(AppContext.BaseDirectory, "Storage", "schema33-fake-images");
    public static async Task<CloudinaryUploadResult> UploadAsync(IFormFile file, CancellationToken ct)
    {
        var ext = file.ContentType switch { "image/jpeg" => ".jpg", "image/png" => ".png", "image/webp" => ".webp", _ => throw new InvalidOperationException("Ảnh giả phải là JPEG/PNG/WebP.") };
        var id = Guid.NewGuid().ToString("N") + ext; Directory.CreateDirectory(Root);
        await using var output = new FileStream(Path.Combine(Root, id), FileMode.CreateNew, FileAccess.Write);
        await file.CopyToAsync(output, ct); return new("/api/trial-media/" + id, "TRIAL_" + id);
    }
    public static Task DeleteAsync(string id)
    {
        if (!id.StartsWith("TRIAL_",StringComparison.Ordinal)) throw new InvalidOperationException("Not a fake media locator.");
        var name = id[6..]; Validate(name); File.Delete(Path.Combine(Root,name)); return Task.CompletedTask;
    }
    private static void Validate(string name)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(name,"^[a-f0-9]{32}\\.(jpg|png|webp)$")) throw new InvalidOperationException("Invalid fake media ID.");
    }
    public static void MapTrialMedia(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/trial-media/{name}", async (string name, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            try { Validate(name); } catch (InvalidOperationException) { return Results.NotFound(); }
            var url="/api/trial-media/"+name;
            var evidence=await db.AnhBienBan.Where(a=>a.DuongDanAnh==url).Join(db.ChiTietHopDong,a=>a.MaChiTietHopDong,d=>d.MaChiTietHopDong,(a,d)=>d.MaHopDong).FirstOrDefaultAsync(ct);
            var review=await db.AnhDanhGia.Where(a=>a.DuongDanAnh==url).Join(db.DanhGia,a=>a.MaDanhGia,r=>r.MaDanhGia,(a,r)=>r).FirstOrDefaultAsync(ct);
            if(evidence!=null){if(!await ApiAccess.CanAccessContractAsync(evidence,p,db,ct))return Results.Forbid();}
            else if(review!=null){if(!ReviewEndpoints.IsPublic(review.TrangThaiKiemDuyet) && !p.IsInRole("ADMIN") && await ApiAccess.CustomerIdAsync(p,db,ct)!=review.MaKhachThue)return Results.Forbid();}
            else return Results.NotFound();
            var path=Path.Combine(Root,name);if(!File.Exists(path))return Results.NotFound();
            return Results.File(path,name.EndsWith(".png")?"image/png":name.EndsWith(".webp")?"image/webp":"image/jpeg");
        });
    }
}
