using Microsoft.Extensions.Options;
using RentalCamera.Api.Chatbot;
using System.Net;
using System.Text;
using System.Text.Json;

public static class ChatbotChecks
{
    public static async Task RunAsync()
    {
        var count = 0;
        void Check(bool ok, string name)
        {
            if (!ok) throw new Exception(name);
            count++;
        }

        Check(ChatPrivacy.Sensitive("OTP 123456"), "Chatbot rejects OTP values");
        Check(ChatPrivacy.Sensitive("email test@example.com"), "Chatbot rejects email addresses");
        Check(ChatPrivacy.Sensitive("Bearer abcdefghijklmnop"), "Chatbot rejects bearer tokens");
        Check(!ChatPrivacy.Sensitive("Tôi muốn thuê máy chụp chân dung"), "Normal rental request is accepted");

        var extracted = ChatPrivacy.Extract("Chụp chân dung, có kinh nghiệm, ngân sách 500k/ngày");
        Check(extracted.Purposes.SequenceEqual(["photo"]), "Purpose is reduced to a controlled label");
        Check(extracted.Genres.SequenceEqual(["portrait"]), "Genre is reduced to a controlled label");
        Check(extracted.Experience.SequenceEqual(["experienced"]), "Experience is reduced to a controlled label");
        Check(extracted.BudgetPerDay == 500_000m, "Budget is parsed without forwarding raw text");

        var faq = new ChatFaq("rent.flow", "Thuê máy thế nào?", "Chọn thiết bị và thời gian thuê.", "backend-contract");
        var evidence = new VerifiedCatalogEvidence("CAM1", "Phù hợp chân dung theo thông số đã duyệt.", "catalog-source");
        var knowledge = new ChatKnowledge([faq], [evidence]);
        var catalog = new FakeCatalog();
        var provider = new FakeProvider(new("availability", ["CAM1", "NOT_IN_CATALOG"], ["rent.flow", "UNKNOWN"]));
        var options = Options.Create(new ChatbotOptions
        {
            Enabled = true,
            LiveApiApproved = true,
            FreePlanConfirmed = true,
            ApiKey = "synthetic-test-key",
            Model = "synthetic-test-model",
            ApprovedKnowledgeSha256 = knowledge.Sha256
        });
        var service = new ChatService(catalog, provider, knowledge, options);

        Check(service.UnavailableReason is null, "Approved chatbot configuration opens the gate");
        Check(service.KnowledgeSha256 == knowledge.Sha256, "Status exposes the exact knowledge approval hash");
        Check(service.Model == "synthetic-test-model", "Configured provider model is reported");

        var reply = await service.ReplyAsync(new ChatRequest(
            "Tôi muốn thuê Canon Alpha chụp chân dung, có kinh nghiệm, ngân sách 500k/ngày", null),
            CancellationToken.None);
        Check(catalog.Calls == 1 && provider.Calls == 1, "Valid request performs one catalog and one provider call");
        Check(provider.LastNeeds?.BudgetPerDay == 500_000m &&
              provider.LastNeeds.Purposes.SequenceEqual(["photo"]),
            "Provider receives normalized needs instead of the conversation text");
        Check(reply.Products.Length == 1 && reply.Products[0].MaDongMay == "CAM1",
            "Only a catalog product with approved evidence is returned");
        Check(reply.Products.All(x => x.MaDongMay != "NOT_IN_CATALOG"),
            "Provider cannot invent product identifiers");
        Check(reply.Sources.Contains("Thuê máy thế nào?") && reply.Sources.Contains("catalog-source"),
            "Reply carries FAQ and product evidence sources");
        Check(reply.Text.Contains(ChatService.Questions["availability"]),
            "Availability is delegated to the dedicated availability flow");

        var handler = new CapturingHandler();
        var groq = new GroqChatProvider(new HttpClient(handler), options);
        var selected = await groq.SelectAsync(extracted, [faq],
            [new("CAM1", "Canon Alpha", "Máy ảnh", "Canon", null, 400_000m, 0m)],
            [evidence], CancellationToken.None);
        Check(selected.ProductIds?.SequenceEqual(["CAM1"]) == true,
            "Provider JSON response is parsed into a bounded selection");
        Check(handler.RequestUri == new Uri("https://api.groq.com/openai/v1/chat/completions") &&
              handler.Authorization == "Bearer synthetic-test-key",
            "Provider uses the fixed HTTPS endpoint and configured bearer key");
        using (var providerRequest = JsonDocument.Parse(handler.RequestBody!))
        {
            Check(providerRequest.RootElement.GetProperty("model").GetString() == "synthetic-test-model",
                "Provider request uses the explicitly configured model");
            Check(!handler.RequestBody!.Contains("Tôi muốn thuê", StringComparison.OrdinalIgnoreCase),
                "Provider request contains no raw customer message");
        }

        var disabledCatalog = new FakeCatalog();
        var disabledProvider = new FakeProvider(new(null, [], []));
        var disabled = new ChatService(disabledCatalog, disabledProvider, knowledge,
            Options.Create(new ChatbotOptions { Enabled = false }));
        var disabledFailure = await FailureAsync(() => disabled.ReplyAsync(
            new ChatRequest("Tôi muốn thuê máy", null), CancellationToken.None));
        Check(disabledFailure.Code == "CHAT_DISABLED" && disabledCatalog.Calls == 0 && disabledProvider.Calls == 0,
            "Disabled gate blocks database and external provider calls");

        var privateFailure = await FailureAsync(() => service.ReplyAsync(
            new ChatRequest("OTP 123456", null), CancellationToken.None));
        Check(privateFailure.Code == "CHAT_PRIVATE" && privateFailure.Status == 400,
            "Sensitive content fails before external processing");

        var stale = new ChatService(new FakeCatalog(), new FakeProvider(new(null, [], [])), knowledge,
            Options.Create(new ChatbotOptions
            {
                Enabled = true,
                LiveApiApproved = true,
                FreePlanConfirmed = true,
                ApiKey = "synthetic-test-key",
                Model = "synthetic-test-model",
                ApprovedKnowledgeSha256 = "stale"
            }));
        Check(stale.UnavailableReason?.Contains("chờ duyệt") == true,
            "Changed knowledge fails closed until its hash is approved again");

        var noModel = new ChatService(new FakeCatalog(), new FakeProvider(new(null, [], [])), knowledge,
            Options.Create(new ChatbotOptions
            {
                Enabled = true,
                LiveApiApproved = true,
                FreePlanConfirmed = true,
                ApiKey = "synthetic-test-key",
                ApprovedKnowledgeSha256 = knowledge.Sha256
            }));
        Check(noModel.UnavailableReason?.Contains("model") == true,
            "Missing provider model fails closed");

        var unapproved = new ChatService(new FakeCatalog(), new FakeProvider(new(null, [], [])), knowledge,
            Options.Create(new ChatbotOptions
            {
                Enabled = true,
                FreePlanConfirmed = true,
                ApiKey = "synthetic-test-key",
                Model = "synthetic-test-model",
                ApprovedKnowledgeSha256 = knowledge.Sha256
            }));
        Check(unapproved.UnavailableReason?.Contains("chưa được phê duyệt") == true,
            "External AI remains blocked without an explicit live API approval");

        Console.WriteLine($"PASS {count} chatbot backend checks; no database, mobile runtime or provider call.");
    }

    private static async Task<ChatFailure> FailureAsync(Func<Task<ChatReply>> action)
    {
        try
        {
            await action();
            throw new Exception("Expected ChatFailure was not thrown.");
        }
        catch (ChatFailure failure)
        {
            return failure;
        }
    }

    private sealed class FakeCatalog : IChatCatalog
    {
        public int Calls { get; private set; }

        public Task<ChatCatalogItem[]> FindAsync(string input, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult<ChatCatalogItem[]>(
            [
                new("CAM1", "Canon Alpha", "Máy ảnh", "Canon", null, 400_000m, 0m),
                new("CAM2", "Sony Cinema", "Máy quay", "Sony", null, 900_000m, 0m)
            ]);
        }
    }

    private sealed class FakeProvider(ProviderSelection selection) : IChatProvider
    {
        public int Calls { get; private set; }
        public NormalizedNeeds? LastNeeds { get; private set; }

        public Task<ProviderSelection> SelectAsync(NormalizedNeeds needs, ChatFaq[] faq,
            ChatCatalogItem[] catalog, VerifiedCatalogEvidence[] evidence, CancellationToken ct)
        {
            Calls++;
            LastNeeds = needs;
            return Task.FromResult(selection);
        }
    }

    private sealed class CapturingHandler : HttpMessageHandler
    {
        public Uri? RequestUri { get; private set; }
        public string? Authorization { get; private set; }
        public string? RequestBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestUri = request.RequestUri;
            Authorization = request.Headers.Authorization?.ToString();
            RequestBody = await request.Content!.ReadAsStringAsync(cancellationToken);
            var selection = JsonSerializer.Serialize(new ProviderSelection(null, ["CAM1"], ["rent.flow"]));
            var envelope = JsonSerializer.Serialize(new
            {
                choices = new[] { new { message = new { content = selection } } }
            });
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(envelope, Encoding.UTF8, "application/json")
            };
        }
    }
}
