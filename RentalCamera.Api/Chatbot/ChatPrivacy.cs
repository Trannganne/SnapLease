using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace RentalCamera.Api.Chatbot;

public static class ChatPrivacy
{
    public static string Normalize(string value)
    {
        var result = new StringBuilder();
        foreach (var c in value.ToLowerInvariant().Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                result.Append(c == 'đ' ? 'd' : c);
        return result.ToString().Normalize(NormalizationForm.FormC);
    }
    public static bool Sensitive(string value) => Regex.IsMatch(Normalize(value),
        @"(?i)\b(?:cccd|cmnd|otp)\b[^\d\r\n]{0,30}\d{4,}|\bbearer\s+\S{8,}|\b(?:password|mat\s*khau|api.?key|access.?token|credential)\s*[:=]\s*\S+|[\w.+-]+@[\w.-]+\.[a-z]{2,}|(?:\d[\s.-]*){9,}|\b(?:sk_|gsk_|pk\.)[a-z0-9_.-]{8,}");

    // Only these controlled labels and a monetary budget leave the Backend.
    // Raw user text and raw conversation history are NEVER sent to the provider.
    public static NormalizedNeeds Extract(string text)
    {
        var normalized = Normalize(text);
        string[] Find(params (string Label, string[] Words)[] entries) => entries
            .Where(x => x.Words.Any(word => Regex.IsMatch(normalized, @"(?<!\w)" + Regex.Escape(word) + @"(?!\w)")))
            .Select(x => x.Label).Distinct().ToArray();
        var purposes = Find(("photo", ["chup", "anh", "photo"]), ("video", ["quay", "video", "vlog"]));
        var genres = Find(("portrait", ["chan dung"]), ("travel", ["du lich"]),
            ("landscape", ["phong canh"]), ("event", ["su kien", "cuoi"]),
            ("sport", ["the thao"]), ("product", ["san pham"]), ("vlog", ["vlog"]));
        var experience = Find(("beginner", ["moi", "lan dau", "chua biet"]),
            ("experienced", ["co kinh nghiem", "chuyen nghiep"]));
        var priorities = Find(("compact", ["nho gon", "nhe"]), ("autofocus", ["lay net", "autofocus"]),
            ("low-light", ["thieu sang", "ban dem"]), ("stabilization", ["chong rung"]));
        var topics = Find(("rent", ["thue", "dat may"]), ("sign", ["ky", "chu ky", "otp"]),
            ("identity", ["cccd", "cmnd", "giay to"]),
            ("deposit", ["coc"]), ("extension", ["gia han"]), ("return", ["tra may", "hoan tra"]),
            ("settlement", ["quyet toan", "hoan tien"]), ("availability", ["lich trong", "con may", "con hang"]));
        decimal? budget = null;
        var match = Regex.Matches(normalized, @"(?<!\d)(\d{1,7})(?:[.,](\d{1,2}))?\s*(trieu|tr|k|nghin|vnd|dong|d)\b").LastOrDefault();
        if (match is { Success: true } && decimal.TryParse(match.Groups[1].Value +
            (match.Groups[2].Success ? "." + match.Groups[2].Value : ""), NumberStyles.Number,
            CultureInfo.InvariantCulture, out var value))
        {
            value *= match.Groups[3].Value is "trieu" or "tr" ? 1_000_000 :
                match.Groups[3].Value is "k" or "nghin" ? 1_000 : 1;
            if (value > 0 && value <= 100_000_000) budget = value;
        }
        return new(purposes, genres, experience, priorities, budget, topics);
    }
}
