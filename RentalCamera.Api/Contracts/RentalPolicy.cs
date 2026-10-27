namespace RentalCamera.Api.Contracts;

public static class RentalPolicy
{
    public const string TermsVersion = "2026-10-20";
    public static readonly string[] ProtectedContracts = ["HD588670599EC646F8AD", "HDC1BF800950C74295A7"];
    // Existing rental API stores Vietnamese wall-clock datetime2, without an offset.
    public static DateTime Utc(DateTime local) => local.Kind == DateTimeKind.Utc ? local :
        DateTime.SpecifyKind(local.Subtract(TimeSpan.FromHours(7)), DateTimeKind.Utc);
    public static DateTime LocalNow => DateTime.SpecifyKind(DateTime.UtcNow.AddHours(7), DateTimeKind.Unspecified);
    public static int LateDays(DateTime effectiveReturn, DateTime received) {
        var late=received-effectiveReturn;
        return late < TimeSpan.FromHours(24) ? 0 : (int)Math.Ceiling(late.TotalDays);
    }
    public static decimal CancellationRate(DateTime pickup, DateTime requested) =>
        pickup-requested >= TimeSpan.FromHours(48) ? 0m : pickup-requested >= TimeSpan.FromHours(24) ? .30m : 1m;
    public static bool CanRequestExtension(HopDongState state, DateTime serverUtc) =>
        state.Status == "DANG_THUE" && !state.Returned && serverUtc <= Utc(state.EffectiveReturn).AddHours(-24);
    public static DateTime SigningDeadline(DateTime approvedUtc, DateTime currentReturn) =>
        approvedUtc.AddHours(2) < Utc(currentReturn) ? approvedUtc.AddHours(2) : Utc(currentReturn);
    public static bool CanUseExtensionTerms(string? originalVersion,bool accepted)=>
        accepted&&(originalVersion==TermsVersion||originalVersion=="1.0");
    public static string[] AppendixTerms(string? originalVersion)=>originalVersion==TermsVersion?Terms:
        [Terms[3],Terms[4],Terms[5],"Phụ lục chỉ thay đổi hạn trả và khoản phí gia hạn nêu trên. Các điều khoản khác của hợp đồng gốc được bảo lưu, gồm chính sách hủy, tiền cọc, trả trễ và ngoại lệ lý do chính đáng đã thỏa thuận; không tự áp chính sách tài chính phiên bản mới lên hợp đồng cũ."];

    public static readonly string[] Terms = [
        "Tiền cọc bảo đảm việc thực hiện thuê và nghĩa vụ đối với tài sản, được đối soát riêng với tiền thuê trả trước.",
        "Hủy trước bàn giao: từ 48 giờ trước hẹn nhận khấu trừ 0%; từ 24 đến dưới 48 giờ khấu trừ 30%; dưới 24 giờ hoặc sau hẹn nhận khi chưa giao khấu trừ 100% tiền cọc hợp lệ thực tế đã thu thành công. Hoàn đủ phần thu thừa; tiền thuê trả trước được đối soát hoàn riêng.",
        "Không nhận sau giờ hẹn đã xác nhận 2 giờ chỉ được xử lý không đến khi có xác nhận khách chưa check-in, lịch hẹn còn hiệu lực và cửa hàng sẵn sàng giao trong giờ phục vụ. Bất khả kháng được xác nhận hoặc lỗi cửa hàng: hoàn đầy đủ khoản đã nhận; bảo lưu cần khách đồng ý. Hủy không có nghĩa tiền đã được chuyển hoàn.",
        "Gia hạn chỉ cho hợp đồng đang thuê, yêu cầu trước hạn trả có hiệu lực ít nhất 24 giờ; cần cửa hàng duyệt và khách ký phụ lục. Không được gia hạn hợp đồng quá hạn bằng cách trả phạt.",
        "Phí gia hạn dùng đơn giá gốc mỗi thiết bị, số ngày kéo dài làm tròn lên theo từng 24 giờ; quyết toán khi trả máy, không thu lại khoảng thuê đã có. Duyệt chưa làm thay đổi hạn trả.",
        "Xử lý gia hạn trong 4 giờ làm việc của chi nhánh, không muộn hơn hạn trả hiện tại trừ 2 giờ. Sau duyệt, khách có tối đa 2 giờ ký và không vượt hạn trả hiện tại. Hết hạn xử lý/ký giữ nguyên hợp đồng gốc.",
        "Trả trễ tính riêng từng thiết bị/serial từ hạn trả có hiệu lực đến lúc cửa hàng thực tế nhận lại: dưới 24 giờ tính 0 ngày; từ 24 giờ tính ceil(tổng số giờ trễ/24), nhân đơn giá thuê/ngày gốc của thiết bị, không thêm hệ số hoặc nhân số lượng hai lần. Ví dụ 24 giờ tính 1 ngày, 24 giờ 1 phút tính 2 ngày. Không trừ 24 giờ rồi mới làm tròn. Chưa nhận lại chỉ là ước tính. Không có miễn/giảm tiền trả trễ; sửa sai thời điểm nhận thực tế cần quyền, lý do và audit.",
        "Chính sách hủy trước bàn giao ở trên là ngoại lệ cụ thể đối với quy định báo trước 10 ngày của mẫu cũ; phụ kiện đi kèm vẫn được ghi nhận/bàn giao. Không bắt buộc giữ CCCD vật lý làm tài sản cầm cố."
    ];
}
public sealed record HopDongState(string Status, DateTime EffectiveReturn, bool Returned);
