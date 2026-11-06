using RentalCamera.Api.Data;

namespace RentalCamera.Api.Contracts;

public static class RentalHistoryPolicy
{
    public static readonly string[] CollectedPaymentTypes =
    [
        "TIEN_COC",
        "TIEN_THUE",
        "PHI_GIA_HAN",
        "PHI_PHAT",
        "THU_QUYET_TOAN"
    ];

    public static bool IsCollectedPayment(ThanhToan payment) =>
        payment.TrangThai == "THANH_CONG" &&
        CollectedPaymentTypes.Contains(payment.LoaiThanhToan, StringComparer.Ordinal);

    public static decimal TotalPaid(IEnumerable<ThanhToan> payments) =>
        payments.Where(IsCollectedPayment).Sum(payment => payment.SoTien);
}
