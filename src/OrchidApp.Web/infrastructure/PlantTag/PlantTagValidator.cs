namespace OrchidApp.Web.Infrastructure.PlantTag;

public static class PlantTagValidator
{
    public static bool IsStructurallyValid(string? tag)
    {
        if (string.IsNullOrWhiteSpace(tag))
            return false;

        // Expected format: AA1-2345
        if (tag.Length != 8)
            return false;

        return
            char.IsLetter(tag[0]) &&
            char.IsLetter(tag[1]) &&
            char.IsDigit(tag[2]) &&
            tag[3] == '-' &&
            char.IsDigit(tag[4]) &&
            char.IsDigit(tag[5]) &&
            char.IsDigit(tag[6]) &&
            char.IsDigit(tag[7]);
    }

    public static bool IsChecksumValid(string tag)
    {
        if (!IsStructurallyValid(tag))
            return false;

        // Extract parts
        var prefix1 = tag[0];
        var prefix2 = tag[1];
        var digit = tag[2] - '0';

        var blockHundreds = tag[4] - '0';
        var blockTens = tag[5] - '0';
        var blockUnits = tag[6] - '0';

        var checksum = tag[7] - '0';

        // Calculate expected checksum
        var calculated =
            prefix1 +
            prefix2 +
            digit +
            blockHundreds +
            blockTens +
            blockUnits;

        calculated = calculated % 10;

        return calculated == checksum;
    }

    public static bool IsValid(string? input)
    {
        var normalised = PlantTagNormaliser.Normalise(input);

        if (normalised is null)
            return false;

        return IsChecksumValid(normalised);
    }
}