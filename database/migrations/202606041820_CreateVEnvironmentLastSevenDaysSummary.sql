CREATE OR REPLACE VIEW venvironmentlastsevendayssummary AS
SELECT
    actual.locationName,
    actual.averageDayTemperatureCelsius,
    target.expectedDayTemperatureCelsius,
    actual.averageNightTemperatureCelsius,
    target.expectedNightTemperatureCelsius,
    actual.averageRelativeHumidity,
    target.expectedRelativeHumidity,
    actual.readingCount,
    actual.firstReadingDateTime,
    actual.lastReadingDateTime
FROM
(
    SELECT
        locationName,
        ROUND(AVG(CASE
            WHEN periodCode = 'DAY' THEN temperatureCelsius
            ELSE NULL
        END), 1) AS averageDayTemperatureCelsius,
        ROUND(AVG(CASE
            WHEN periodCode = 'NIGHT' THEN temperatureCelsius
            ELSE NULL
        END), 1) AS averageNightTemperatureCelsius,
        ROUND(AVG(relativeHumidity), 1) AS averageRelativeHumidity,
        COUNT(*) AS readingCount,
        MIN(readingDateTime) AS firstReadingDateTime,
        MAX(readingDateTime) AS lastReadingDateTime
    FROM venvironmentreadingperiod
    WHERE readingDateTime >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      AND readingDateTime < DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)
    GROUP BY
        locationName
) actual
INNER JOIN environmenttargetrule target
    ON target.locationName = actual.locationName
    AND target.monthNumber = MONTH(CURRENT_DATE())
    AND target.isActive = 1
    AND CURRENT_DATE() >= target.effectiveFromDate
    AND (
        target.effectiveToDate IS NULL
        OR CURRENT_DATE() < target.effectiveToDate
    );