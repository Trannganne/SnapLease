using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Chatbot;

public sealed class ChatService(IChatCatalog catalog, IChatProvider provider,
    ChatKnowledge knowledge, IOptions<ChatbotOptions> options)
{
    public string? UnavailableReason => !options.Value.Enabled ? "Trợ lý AI chưa được bật." :
        !options.Value.FreePlanConfirmed ? "Chưa xác nhận tài khoản AI thuộc gói miễn phí." :
        string.IsNullOrWhiteSpace(options.Value.ApiKey) ? "Trợ lý AI chưa được cấu hình." :
        !string.Equals(options.Value.ApprovedKnowledgeSha256, knowledge.Sha256, StringComparison.OrdinalIgnoreCase)
            ? "Nguồn kiến thức đang chờ duyệt hoặc đã thay đổi." : null;

    public static readonly Dictionary<string, string> Questions = new() {
        ["purpose"] = "Bạn cần máy để chụp ảnh, quay video hay cả hai?",
        ["genre"] = "Bạn dự định chụp/quay thể loại nào: chân dung, du lịch, sự kiện hay sản phẩm?",
        ["budget"] = "Ngân sách thuê mỗi ngày của bạn khoảng bao nhiêu? Hãy ghi rõ đơn vị, ví dụ 500k/ngày.",
        ["experience"] = "Bạn mới sử dụng máy ảnh hay đã có kinh nghiệm?",
        ["preferences"] = "Bạn ưu tiên điều gì ở thiết bị, chẳng hạn nhỏ gọn hoặc dễ sử dụng?",
        ["availability"] = "Hãy chọn chi nhánh và thời gian trong mục Kiểm tra lịch trống của thiết bị. Chưa đủ dữ liệu để kết luận còn máy."
    };

    public async Task<ChatReply> ReplyAsync(ChatRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Message) || request.Message.Length > 1200 ||
            (request.History?.Length ?? 0) > 6 || request.History?.Any(x =>
                x is null || x.Role is not ("user" or "assistant") || x.Text is null || x.Text.Length > 1200) == true)
            throw new ChatFailure("CHAT_INPUT", "Tin nhắn không hợp lệ hoặc quá dài (tối đa 1.200 ký tự).", 400);
        if (ChatPrivacy.Sensitive(request.Message) || request.History?.Any(x => ChatPrivacy.Sensitive(x.Text)) == true)
            throw new ChatFailure("CHAT_PRIVATE", "Không nhập CCCD, OTP, số điện thoại, email, mật khẩu hoặc token vào trợ lý.", 400);
        if (UnavailableReason is string reason) throw new ChatFailure("CHAT_DISABLED", reason);

        var recent = (request.History ?? []).Where(x => x.Role == "user").TakeLast(3).Select(x => x.Text);
        var needs = ChatPrivacy.Extract(string.Join(" ", recent.Append(request.Message)));
        var rows = await catalog.FindAsync(request.Message, ct);
        var input = ChatPrivacy.Normalize(request.Message);
        needs = needs with { CatalogIds = rows.Where(row => input.Contains(ChatPrivacy.Normalize(row.Name)) ||
            (!string.IsNullOrWhiteSpace(row.Brand) && input.Contains(ChatPrivacy.Normalize(row.Brand))))
            .Select(row => row.Id).ToArray() };
        if (needs.Purposes.Length == 0 && needs.Genres.Length == 0 && needs.Topics.Length == 0 && needs.CatalogIds.Length == 0)
            return new ChatReply("Mình hỗ trợ thuê, ký, cọc, gia hạn, trả máy và tư vấn thiết bị trong catalog. Với nội dung ngoài phạm vi hoặc chưa đủ dữ liệu, bạn vui lòng liên hệ chi nhánh. " + Questions["purpose"], [], [], DateTime.UtcNow);
        var evidence = knowledge.Evidence.Where(x => rows.Any(row => row.Id == x.Id) &&
            !string.IsNullOrWhiteSpace(x.Summary) && !string.IsNullOrWhiteSpace(x.Source) &&
            !ChatPrivacy.Sensitive(x.Summary)).Take(8).ToArray();
        var faqIds = needs.Topics.SelectMany(topic => topic switch {
            "rent" => new[]{"rent.flow"}, "sign" => ["sign.flow"], "identity" => ["terms.8"], "deposit" => ["deposit.status","terms.1"],
            "extension" => ["terms.4","terms.5","terms.6"], "return" => ["return.flow","terms.7"],
            "settlement" => ["return.flow","terms.1"], "availability" => ["availability.flow"], _ => Array.Empty<string>()
        }).Distinct().ToArray();
        var relevantFaq = knowledge.Faq.Where(x => faqIds.Contains(x.Id)).Take(3).ToArray();
        var selection = await provider.SelectAsync(needs, relevantFaq, rows, evidence, ct);
        var faqs = (selection.FaqIds ?? []).Distinct().Take(2)
            .Select(id => relevantFaq.FirstOrDefault(x => x.Id == id)).OfType<ChatFaq>().ToArray();
        var products = (selection.ProductIds ?? []).Distinct().Take(3)
            .Select(id => rows.FirstOrDefault(row => row.Id == id && evidence.Any(e => e.Id == id) &&
                (needs.BudgetPerDay is null || row.PricePerDay <= needs.BudgetPerDay)))
            .OfType<ChatCatalogItem>().Select(row => new ChatProduct(row.Id, row.Name, row.Image,
                row.PricePerDay, row.Discount, row.Category, evidence.First(e => e.Id == row.Id).Summary)).ToArray();
        var parts = faqs.Select(x => x.Answer).ToList();
        if (products.Length > 0) {
            var missing = needs.Purposes.Length == 0 ? "purpose" : needs.Genres.Length == 0 ? "genre" :
                needs.BudgetPerDay is null ? "budget" : needs.Experience.Length == 0 ? "experience" : null;
            if (missing is not null) {
                products = [];
                parts.Add(Questions[missing]);
            }
        }
        if (selection.QuestionKey is string key && Questions.TryGetValue(key, out var question)) parts.Add(question);
        if (evidence.Length == 0 && products.Length == 0) {
            parts.Add("Catalog chưa có mô tả/thông số kèm nguồn xác minh để tư vấn theo tính năng. Cần cửa hàng bổ sung trước khi gợi ý thiết bị theo nhu cầu.");
            // Search results are explicitly distinct from AI suitability recommendations.
            var named = rows.Where(row => ChatPrivacy.Normalize(request.Message).Contains(ChatPrivacy.Normalize(row.Name))).Take(3);
            products = named.Select(row => new ChatProduct(row.Id, row.Name, row.Image, row.PricePerDay,
                row.Discount, row.Category, null)).ToArray();
        }
        if (parts.Count == 0 && products.Length == 0)
            parts.Add("Mình chưa đủ dữ liệu để trả lời nội dung này. Bạn có thể hỏi về thuê, ký, cọc, gia hạn, trả máy hoặc liên hệ chi nhánh.");
        if (products.Length > 0) parts.Add("Các thẻ lấy từ catalog hiện hành; phù hợp nhu cầu không có nghĩa là còn máy. Kiểm tra chi nhánh và thời gian trước khi thuê.");
        return new ChatReply(string.Join("\n\n", parts), products,
            faqs.Select(x => x.Id.StartsWith("terms.") ? $"Điều khoản thuê {RentalCamera.Api.Contracts.RentalPolicy.TermsVersion}" : x.Question)
                .Concat(products.SelectMany(p => evidence.Where(e => e.Id == p.MaDongMay).Select(e => e.Source))).Distinct().ToArray(), DateTime.UtcNow);
    }
}
