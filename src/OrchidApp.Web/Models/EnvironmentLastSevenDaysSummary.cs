using System;

namespace OrchidApp.Web.Models;

public class EnvironmentLastSevenDaysSummary
{
    public string LocationName { get; set; } = string.Empty;

    public decimal? AverageDayTemperatureCelsius { get; set; }
    public decimal ExpectedDayTemperatureCelsius { get; set; }

    public decimal? AverageNightTemperatureCelsius { get; set; }
    public decimal ExpectedNightTemperatureCelsius { get; set; }

    public decimal? AverageRelativeHumidity { get; set; }
    public decimal ExpectedRelativeHumidity { get; set; }

    public long ReadingCount { get; set; }

    public DateTime? FirstReadingDateTime { get; set; }
    public DateTime? LastReadingDateTime { get; set; }
}