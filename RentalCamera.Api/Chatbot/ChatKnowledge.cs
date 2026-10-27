using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using RentalCamera.Api.Contracts;

namespace RentalCamera.Api.Chatbot;

public sealed class ChatKnowledge
{
    public ChatFaq[] Faq { get; }
    public VerifiedCatalogEvidence[] Evidence { get; }
    public string Sha256 { get; }
    public ChatKnowledge(ChatFaq[] faq, VerifiedCatalogEvidence[] evidence)
    {
        Faq = faq.Concat(RentalPolicy.Terms.Select((text, i) => new ChatFaq(
            $"terms.{i + 1}", "Điều khoản thuê hiện hành", text,
            $"RentalPolicy.Terms/{RentalPolicy.TermsVersion}/{i + 1}"))).ToArray();
        Evidence = evidence;
        Sha256 = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            JsonSerializer.Serialize(new { Faq, Evidence })))).ToLowerInvariant();
    }
    public static ChatKnowledge Load(string root)
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        return new ChatKnowledge(
            JsonSerializer.Deserialize<ChatFaq[]>(File.ReadAllText(Path.Combine(root, "Knowledge", "faq.vi.json")), options) ?? [],
            JsonSerializer.Deserialize<VerifiedCatalogEvidence[]>(File.ReadAllText(Path.Combine(root, "Knowledge", "catalog-evidence.vi.json")), options) ?? []);
    }
}
