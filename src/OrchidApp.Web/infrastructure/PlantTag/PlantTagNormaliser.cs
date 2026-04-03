namespace OrchidApp.Web.Infrastructure.PlantTag;

public static class PlantTagNormaliser
{
    public static string? Normalise(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
            return null;

        // Remove whitespace and hyphens
        var cleaned = input
            .Replace("-", "")
            .Replace(" ", "")
            .Trim()
            .ToUpperInvariant();

        // Expect exactly 7 characters (AANNNNC)
        if (cleaned.Length != 7)
            return null;

        // Reinsert hyphen → AA1-2345
        return $"{cleaned.Substring(0, 3)}-{cleaned.Substring(3)}";
    }
}