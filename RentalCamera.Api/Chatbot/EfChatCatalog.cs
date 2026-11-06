using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Chatbot;

public sealed class EfChatCatalog(RentalCameraContext db) : IChatCatalog
{
    public async Task<ChatCatalogItem[]> FindAsync(string input, CancellationToken ct)
    {
        // Public catalog projection only. No customer, contract or payment query.
        var models = await db.DongMay.AsNoTracking().Include(x => x.DanhMuc).Include(x => x.ThuongHieu)
            .Include(x => x.AnhThietBi).OrderBy(x => x.TenDongMay).Take(100).ToArrayAsync(ct);
        var rows = models.Select(x => new ChatCatalogItem(x.MaDongMay, x.TenDongMay, x.DanhMuc.TenDanhMuc,
            x.ThuongHieu.TenThuongHieu,
            x.AnhThietBi.Where(a => a.LaAnhDaiDien).Select(a => a.DuongDanAnh).FirstOrDefault(),
            x.GiaThueNgay, RentalPromotionPolicy.EffectiveCatalogPercent(x))).ToArray();
        var words = ChatPrivacy.Normalize(input).Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Where(x => x.Length > 2).Distinct().ToArray();
        return rows.OrderByDescending(row => words.Count(word =>
            ChatPrivacy.Normalize(row.Name + " " + row.Brand + " " + row.Category).Contains(word)))
            .ThenBy(row => row.Name).Take(8).ToArray();
    }
}
