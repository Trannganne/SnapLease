using RentalCamera.Api.Data;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Settlement;
using Microsoft.EntityFrameworkCore;

namespace RentalCamera.Api.Infrastructure;

public static class ContractOperation
{
    public static bool Valid(string? id) => !string.IsNullOrWhiteSpace(id) && id.Length <= 100;
    public static string Hash(string contract, string actor, object body, string? target = null) =>
        SettlementJson.Hash(SettlementJson.Write(new { contract, actor, target, body }));
    public static async Task<bool> ReplayAsync(RentalCameraContext db, HopDong h, string operation,
        string key, string hash, CancellationToken ct)
    {
        var found = await db.IdempotencyKey.SingleOrDefaultAsync(k => k.MaKhachThue == h.MaKhachThue &&
            k.LoaiThaoTac == operation && k.IdempotencyKey == key, ct);
        if (found == null) return false;
        if (found.PayloadHash != hash || found.MaThucThe != h.MaHopDong)
            throw new InvalidOperationException("Mã thao tác đã dùng cho nội dung hoặc người thực hiện khác.");
        return true;
    }
    public static void Record(RentalCameraContext db, HopDong h, string operation, string key, string hash) =>
        db.IdempotencyKey.Add(new() { IdempotencyKey = key, MaKhachThue = h.MaKhachThue,
            LoaiThaoTac = operation, PayloadHash = hash, MaThucThe = h.MaHopDong, NgayTao = RentalPolicy.LocalNow });
}
