CREATE OR REPLACE VIEW venvironmentreadingperiod AS
SELECT
    er.environmentReadingId,
    er.sensorName,
    es.locationName,
    er.readingDateTime,

    epr.periodCode,
    epr.periodName,

    CASE
        WHEN epr.endTime > epr.startTime THEN DATE(er.readingDateTime)
        WHEN TIME(er.readingDateTime) >= epr.startTime THEN DATE(er.readingDateTime)
        ELSE DATE_SUB(DATE(er.readingDateTime), INTERVAL 1 DAY)
    END AS periodDate,

    er.temperatureCelsius,
    er.relativeHumidity
FROM environmentreading er
INNER JOIN environmentsensor es
    ON es.sensorName = er.sensorName
    AND es.isActive = 1
    AND DATE(er.readingDateTime) >= es.effectiveFromDate
    AND (
        es.effectiveToDate IS NULL
        OR DATE(er.readingDateTime) < es.effectiveToDate
    )
INNER JOIN environmentperiodrule epr
    ON epr.isActive = 1
    AND DATE(er.readingDateTime) >= epr.effectiveFromDate
    AND (
        epr.effectiveToDate IS NULL
        OR DATE(er.readingDateTime) < epr.effectiveToDate
    )
    AND (
        (
            epr.endTime > epr.startTime
            AND TIME(er.readingDateTime) >= epr.startTime
            AND TIME(er.readingDateTime) < epr.endTime
        )
        OR
        (
            epr.endTime < epr.startTime
            AND (
                TIME(er.readingDateTime) >= epr.startTime
                OR TIME(er.readingDateTime) < epr.endTime
            )
        )
    )
WHERE er.isActive = 1
  AND es.locationName IS NOT NULL;