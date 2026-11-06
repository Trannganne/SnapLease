using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Rental;

public sealed record RentalPromotionDecision(
    decimal Percent, bool IsNewCustomer, bool HasThreeOrMoreDevices, string[] Codes)
{
    public decimal Apply(decimal amount) =>
        Math.Round(amount * (100m - Percent) / 100m, 2);
}

public static class RentalPromotionPolicy
{
    public const decimal PromotionPercent = 10m;
    public const int BulkMinimumQuantity = 3;

    public static RentalPromotionDecision Evaluate(int totalQuantity, bool isNewCustomer)
    {
        var bulk = totalQuantity >= BulkMinimumQuantity;
        var codes = new List<string>(2);
        if (isNewCustomer) codes.Add("KHACH_HANG_MOI_10");
        if (bulk) codes.Add("THUE_3_THIET_BI_10");
        return new(codes.Count == 0 ? 0m : PromotionPercent, isNewCustomer, bulk, [.. codes]);
    }

    public static decimal EffectiveCatalogPercent(DongMay model, DateTime? atUtc = null)
    {
        if (model.PhanTramGiamGia <= 0) return 0m;
        if (model.TGBatDau is null && model.TGKetThuc is null)
            return model.PhanTramGiamGia; // Backward-compatible catalog data.
        if (model.TGBatDau is null || model.TGKetThuc is null || model.TGKetThuc <= model.TGBatDau)
            return 0m;
        var at = atUtc ?? DateTime.UtcNow;
        return at >= model.TGBatDau.Value && at < model.TGKetThuc.Value
            ? model.PhanTramGiamGia
            : 0m;
    }

    public static decimal EffectiveCatalogPrice(DongMay model, DateTime? atUtc = null) =>
        Math.Round(model.GiaThueNgay * (100m - EffectiveCatalogPercent(model, atUtc)) / 100m, 2);

    // A customer is new until the first contract is created. Counting every contract
    // state prevents repeatedly claiming the promotion through abandoned unsigned contracts.
    public static async Task<bool> IsNewCustomerAsync(
        RentalCameraContext db, string customerId, CancellationToken ct) =>
        !await db.HopDong.AnyAsync(x => x.MaKhachThue == customerId, ct);
}
