namespace OrchidApp.Web.Models;

public sealed record GreenhouseNetCost(string Period, decimal? SignedAmount, decimal HeaterKwh = 0,
    decimal SolarKwh = 0, string? UnavailableReason = null)
{
    public string Label => SignedAmount is null ? "Cost / Saved" : SignedAmount < 0 ? "Saved" : "Cost";
    public string DisplayAmount => SignedAmount is { } value
        ? Math.Abs(value).ToString("C2", System.Globalization.CultureInfo.GetCultureInfo("en-GB")) : "—";
}

public sealed record GreenhouseNetCosts(GreenhouseNetCost LastSevenDays, GreenhouseNetCost YearToDate)
{
    public static GreenhouseNetCosts Unavailable(string reason) => new(
        new("Last 7 days", null, UnavailableReason: reason),
        new("Year to date", null, UnavailableReason: reason));
}

public sealed class GreenhouseSolarHour
{
    public DateTime AtUtc { get; set; }
    public decimal ProducedWh { get; set; }
    public long ReadingCount { get; set; }
    public long InvalidCount { get; set; }
}
