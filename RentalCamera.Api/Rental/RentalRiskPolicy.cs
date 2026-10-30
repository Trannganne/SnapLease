using Microsoft.Extensions.Configuration;

namespace RentalCamera.Api.Rental;

public static class RentalRiskPolicy
{
    public const int DefaultBufferMinutes = 120;
    public const int DefaultStandardMaxQuantity = 10;
    public const int DefaultHighValueMaxQuantity = 3;
    public const decimal DefaultHighValueDepositThreshold = 10_000_000m;

    public static int BufferMinutes(IConfiguration configuration) =>
        Math.Clamp(configuration.GetValue("Rental:BufferMinutes", DefaultBufferMinutes), 0, 1440);

    public static int StandardMaxQuantity(IConfiguration configuration) =>
        Math.Clamp(configuration.GetValue("Rental:StandardMaxQuantity", DefaultStandardMaxQuantity), 1, 100);

    public static int HighValueMaxQuantity(IConfiguration configuration) =>
        Math.Clamp(configuration.GetValue("Rental:HighValueMaxQuantity", DefaultHighValueMaxQuantity), 1,
            StandardMaxQuantity(configuration));

    public static decimal HighValueDepositThreshold(IConfiguration configuration) =>
        Math.Clamp(configuration.GetValue("Rental:HighValueDepositThreshold", DefaultHighValueDepositThreshold), 0m,
            1_000_000_000m);

    public static bool IsHighValue(decimal deposit, IConfiguration configuration) =>
        deposit >= HighValueDepositThreshold(configuration);

    public static DateTime OccupiedUntil(
        DateTime scheduledReturn,
        DateTime? actualReturn,
        string contractStatus,
        DateTime localNow,
        IConfiguration configuration)
    {
        if (actualReturn.HasValue)
            return actualReturn.Value.AddMinutes(BufferMinutes(configuration));
        if (contractStatus is "DANG_THUE" or "CHO_HOAN_TRA" && scheduledReturn <= localNow)
            return DateTime.MaxValue;
        return scheduledReturn.AddMinutes(BufferMinutes(configuration));
    }

    public static RentalLimitDecision Evaluate(
        IEnumerable<(decimal Deposit, int Quantity)> items,
        IConfiguration configuration)
    {
        var standardMaximum = StandardMaxQuantity(configuration);
        var highValueMaximum = HighValueMaxQuantity(configuration);
        var threshold = HighValueDepositThreshold(configuration);
        var materialized = items.ToArray();
        var highValueQuantity = materialized
            .Where(x => x.Deposit >= threshold)
            .Sum(x => x.Quantity);
        var invalidStandardQuantity = materialized.Any(x => x.Quantity is < 1 || x.Quantity > standardMaximum);

        return new RentalLimitDecision(
            !invalidStandardQuantity && highValueQuantity <= highValueMaximum,
            highValueQuantity,
            highValueMaximum,
            standardMaximum,
            threshold);
    }

    public static object LimitError(RentalLimitDecision decision) => new
    {
        code = "HIGH_VALUE_QUANTITY_LIMIT",
        loi = $"Một lượt thuê chỉ được tối đa {decision.HighValueMaximum} thiết bị giá trị cao.",
        soLuongGiaTriCao = decision.HighValueQuantity,
        toiDaThietBiGiaTriCao = decision.HighValueMaximum,
        nguongTienCoc = decision.HighValueDepositThreshold
    };
}

public sealed record RentalLimitDecision(
    bool Allowed,
    int HighValueQuantity,
    int HighValueMaximum,
    int StandardMaximum,
    decimal HighValueDepositThreshold);
