namespace RentalCamera.Api.Chatbot;

public sealed class ChatbotOptions
{
    public bool Enabled { get; set; }
    public bool FreePlanConfirmed { get; set; }
    public string ApiKey { get; set; } = "";
    public string ApprovedKnowledgeSha256 { get; set; } = "";
    public const string Model = "qwen/qwen3.8-27b";
}

public sealed record ChatTurn(string Role, string Text);
public sealed record ChatRequest(string Message, ChatTurn[]? History);
public sealed record ChatProduct(string MaDongMay, string TenDongMay, string? AnhDaiDien,
    decimal GiaThueNgay, decimal PhanTramGiamGia, string TenDanhMuc, string? Reason);
public sealed record ChatReply(string Text, ChatProduct[] Products, string[] Sources, DateTime ObservedAtUtc);
public sealed record ChatCatalogItem(string Id, string Name, string Category, string Brand,
    string? Image, decimal PricePerDay, decimal Discount);
public sealed record VerifiedCatalogEvidence(string Id, string Summary, string Source);
public sealed record ChatFaq(string Id, string Question, string Answer, string Source);
public sealed record ProviderSelection(string? QuestionKey, string[]? ProductIds, string[]? FaqIds);
public sealed record NormalizedNeeds(string[] Purposes, string[] Genres, string[] Experience,
    string[] Priorities, decimal? BudgetPerDay, string[] Topics, string[]? CatalogIds = null);

public sealed class ChatFailure(string code, string message, int status = 503) : Exception(message)
{
    public string Code { get; } = code;
    public int Status { get; } = status;
}

public interface IChatCatalog
{
    Task<ChatCatalogItem[]> FindAsync(string input, CancellationToken ct);
}
public interface IChatProvider
{
    Task<ProviderSelection> SelectAsync(NormalizedNeeds needs, ChatFaq[] faq,
        ChatCatalogItem[] catalog, VerifiedCatalogEvidence[] evidence, CancellationToken ct);
}
