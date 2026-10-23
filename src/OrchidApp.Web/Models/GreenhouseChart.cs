namespace OrchidApp.Web.Models;

public sealed record ChartPoint(double X, decimal? Y);
public sealed record PeriodSegment(double Start, double End, decimal? Average, decimal? Target,
    string Label, long ReadingCount, string Status);
public sealed class GreenhouseChart
{
    public string LocationName { get; init; } = "";
    public string RangeLabel { get; init; } = "";
    public List<string> Labels { get; init; } = [];
    public List<ChartPoint> Costs { get; init; } = [];
    public List<ChartPoint> Temperatures { get; init; } = [];
    public List<PeriodSegment> Periods { get; init; } = [];
    public List<string> Notices { get; init; } = [];
}

public sealed class GreenhouseReading
{
    public long Id { get; set; }
    public string LocationName { get; set; } = "";
    public DateTime At { get; set; }
    public decimal Temperature { get; set; }
}
public sealed class GreenhousePeriodReading
{
    public long Id { get; set; }
    public string LocationName { get; set; } = "";
    public DateTime At { get; set; }
    public string PeriodCode { get; set; } = "";
    public DateTime PeriodDate { get; set; }
    public decimal Temperature { get; set; }
}
public sealed class GreenhousePeriodRule
{
    public string PeriodCode { get; set; } = "";
    public string PeriodName { get; set; } = "";
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public DateTime EffectiveFromDate { get; set; }
    public DateTime? EffectiveToDate { get; set; }
}
public sealed class GreenhouseTarget
{
    public string LocationName { get; set; } = "";
    public int MonthNumber { get; set; }
    public decimal DayTarget { get; set; }
    public decimal NightTarget { get; set; }
    public DateTime EffectiveFromDate { get; set; }
    public DateTime? EffectiveToDate { get; set; }
}
public sealed class GreenhouseEnergy
{
    public int DeviceId { get; set; }
    public DateTime AtUtc { get; set; }
    public int? EnergyWh { get; set; }
}
public sealed class GreenhouseTariff
{
    public DateTime EffectiveFromDate { get; set; }
    public DateTime? EffectiveToDate { get; set; }
    public decimal RatePence { get; set; }
}
public sealed class GreenhouseAssignment
{
    public int DeviceId { get; set; }
    public string LocationName { get; set; } = "";
    public DateTime Start { get; set; }
    public DateTime? End { get; set; }
}

public sealed class GreenhouseHour
{
    public string LocationName { get; set; } = "";
    public DateTime At { get; set; }
    public decimal? Average { get; set; }
    public long ReadingCount { get; set; }
    public long ConflictCount { get; set; }
}
public sealed class GreenhousePeriodAggregate
{
    public string LocationName { get; set; } = "";
    public string PeriodCode { get; set; } = "";
    public DateTime PeriodDate { get; set; }
    public decimal TemperatureSum { get; set; }
    public long ReadingCount { get; set; }
    public DateTime FirstReading { get; set; }
    public DateTime LastReading { get; set; }
    public long ConflictCount { get; set; }
}
