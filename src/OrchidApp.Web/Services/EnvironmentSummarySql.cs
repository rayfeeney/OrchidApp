namespace OrchidApp.Web.Services;

public static class EnvironmentSummarySql
{
    // Same reading-weighted summary and eight-date window as the existing view,
    // with London "today" supplied by C# rather than the database server clock.
    // Aggregate target matches so invalid overlaps cannot duplicate location cards.
    public const string Query = """
        SELECT a.locationName, a.averageDayTemperatureCelsius,
               t.expectedDayTemperatureCelsius, a.averageNightTemperatureCelsius,
               t.expectedNightTemperatureCelsius, a.averageRelativeHumidity,
               t.expectedRelativeHumidity, a.readingCount,
               a.firstReadingDateTime, a.lastReadingDateTime
        FROM (
            SELECT locationName,
                   ROUND(AVG(CASE WHEN periodCode = 'DAY' THEN temperatureCelsius END), 1) AS averageDayTemperatureCelsius,
                   ROUND(AVG(CASE WHEN periodCode = 'NIGHT' THEN temperatureCelsius END), 1) AS averageNightTemperatureCelsius,
                   ROUND(AVG(relativeHumidity), 1) AS averageRelativeHumidity,
                   COUNT(*) AS readingCount, MIN(readingDateTime) AS firstReadingDateTime,
                   MAX(readingDateTime) AS lastReadingDateTime
            FROM venvironmentreadingperiod
            WHERE readingDateTime >= {0} - INTERVAL 7 DAY AND readingDateTime < {0} + INTERVAL 1 DAY
            GROUP BY locationName
        ) a
        LEFT JOIN (
            SELECT locationName,
                   CASE WHEN COUNT(*) = 1 THEN MAX(expectedDayTemperatureCelsius) END AS expectedDayTemperatureCelsius,
                   CASE WHEN COUNT(*) = 1 THEN MAX(expectedNightTemperatureCelsius) END AS expectedNightTemperatureCelsius,
                   CASE WHEN COUNT(*) = 1 THEN MAX(expectedRelativeHumidity) END AS expectedRelativeHumidity
            FROM environmenttargetrule
            WHERE monthNumber = MONTH({0}) AND isActive = 1 AND {0} >= effectiveFromDate
              AND (effectiveToDate IS NULL OR {0} < effectiveToDate)
            GROUP BY locationName
        ) t ON t.locationName = a.locationName
        """;
}
