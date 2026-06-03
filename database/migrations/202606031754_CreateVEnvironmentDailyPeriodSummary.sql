CREATE OR REPLACE VIEW venvironmentdailyperiodsummary AS
SELECT
    locationName,
    periodCode,
    periodName,
    periodDate,

    COUNT(*) AS readingCount,

    ROUND(AVG(temperatureCelsius), 1) AS averageTemperatureCelsius,
    ROUND(AVG(relativeHumidity), 1) AS averageRelativeHumidity,

    MIN(readingDateTime) AS firstReadingDateTime,
    MAX(readingDateTime) AS lastReadingDateTime
FROM venvironmentreadingperiod
GROUP BY
    locationName,
    periodCode,
    periodName,
    periodDate;