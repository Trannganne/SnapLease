using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Chatbot;

public sealed class EfChatCatalog(RentalCameraContext db) : IChatCatalog
{
    public async Task<ChatCatalogItem[]> FindAsync(string input, CancellationToken ct)
    {
        // Public catalog projection only. No customer, contract or payment query.
        var rows = await db.DongMay.AsNoTracking().OrderBy(x => x.TenDongMay).Take(100)
            .Select(x => new ChatCatalogItem(x.MaDongMay, x.TenDongMay, x.DanhMuc.TenDanhMuc,
                x.ThuongHieu.TenThuongHieu,
                x.AnhThietBi.Where(a => a.LaAnhDaiDien).Select(a => a.DuongDanAnh).FirstOrDefault(),
                x.GiaThueNgay, x.PhanTramGiamGia)).ToArrayAsync(ct);
        var words = ChatPrivacy.Normalize(input).Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Where(x => x.Length > 2).Distinct().ToArray();
        return rows.OrderByDescending(row => words.Count(word =>
            ChatPrivacy.Normalize(row.Name + " " + row.Brand + " " + row.Category).Contains(word)))
            .ThenBy(row => row.Name).Take(8).ToArray();
    }
}
