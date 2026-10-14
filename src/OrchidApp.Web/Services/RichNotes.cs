using System.Text;
using System.Text.Encodings.Web;
using AngleSharp.Dom;
using AngleSharp.Html.Parser;
using Ganss.Xss;
using Microsoft.AspNetCore.Html;

namespace OrchidApp.Web.Services;

// The marker distinguishes new HTML from historical text without guessing from tags.
public static class RichNotes
{
    public const string Marker = "<!--orchid-rich-notes:v1-->";
    public const int MaxTextLength = 10000;
    public const int MaxStorageBytes = 60000; // MariaDB TEXT allows 65,535 bytes.
    public const int MaxInputLength = 200000;

    public static bool IsFormatted(string? value) => value?.StartsWith(Marker, StringComparison.Ordinal) == true;

    public static string EditorHtml(string? value) => IsFormatted(value)
        ? Sanitize(value![Marker.Length..])
        : string.Join("<br>", (value ?? "").Replace("\r\n", "\n").Replace("\r", "\n")
            .Split('\n').Select(line => HtmlEncoder.Default.Encode(line)));

    public static IHtmlContent Display(string? value) => new HtmlString(
        string.IsNullOrWhiteSpace(value) ? "—" : EditorHtml(value));

    public static string? PrepareForSave(string? input)
    {
        if (input == null) return null;
        if (input.Length > MaxInputLength)
            throw new ArgumentException("The pasted note is too large. Please shorten it before saving.");
        var html = Sanitize(EditorHtml(input));
        var document = new HtmlParser().ParseDocument(html);
        var text = document.Body!.TextContent;
        if (text.Length > MaxTextLength)
            throw new ArgumentException($"Notes must contain no more than {MaxTextLength:N0} characters.");
        if (string.IsNullOrWhiteSpace(text)) return null;
        var stored = Marker + html;
        if (Encoding.UTF8.GetByteCount(stored) > MaxStorageBytes)
            throw new ArgumentException("The formatted note is too large to store. Please shorten it or remove some formatting.");
        return stored;
    }

    private static string Sanitize(string html)
    {
        var sanitizer = new HtmlSanitizer { KeepChildNodes = true };
        sanitizer.AllowedTags.Clear();
        foreach (var tag in new[] { "p", "br", "strong", "em", "u", "ol", "ul", "li" })
            sanitizer.AllowedTags.Add(tag);
        sanitizer.AllowedAttributes.Clear();
        sanitizer.AllowedCssProperties.Clear();
        sanitizer.AllowedSchemes.Clear();
        var parser = new HtmlParser();
        var document = parser.ParseDocument(sanitizer.Sanitize(html));
        CleanText(document.Body!);
        // Serialisation encodes cleaned text again; text can never become executable markup.
        return document.Body!.InnerHtml;
    }

    private static void CleanText(INode node)
    {
        if (node is IText text)
        {
            var clean = new StringBuilder();
            foreach (var rune in text.Data.EnumerateRunes())
            {
                if (rune.Value is 0x200B or 0x2060 or 0xFEFF) continue;
                if (rune.Value is 0x00A0 or 9) { clean.Append(' '); continue; }
                if (Rune.IsControl(rune) && rune.Value is not 10 and not 13) continue;
                // Preserve accents, punctuation, emoji and joining characters; never ASCII-strip.
                clean.Append(rune.ToString());
            }
            text.Data = clean.ToString().Normalize(NormalizationForm.FormC);
        }
        foreach (var child in node.ChildNodes) CleanText(child);
    }
}
