USE orchids;

DROP VIEW IF EXISTS vplantlifecyclehistory;

CREATE OR REPLACE
SQL SECURITY INVOKER
VIEW vplantlifecyclehistory AS

WITH plant_identity AS (
    SELECT p.plantId
    FROM plant p
    WHERE p.isActive = 1
)

-- Observation
SELECT
    pi.plantId,
    pe.eventDateTime,
    'Observation'  AS eventType,
    pe.eventDetails  AS eventSummary,
    'plantevent'  AS sourceTable,
    pe.plantEventId AS sourceId
FROM plant_identity pi
JOIN plantevent pe ON pe.plantId = pi.plantId
WHERE pe.isActive = 1

UNION ALL

-- Repotting
SELECT
    pi.plantId,
    CAST(r.repotDate AS DATETIME) AS eventDateTime,
    'Repotting'  AS eventType,
    (
        CONCAT(
            'Repotted',
            CASE
                WHEN r.oldGrowthMediumId IS NOT NULL AND r.newGrowthMediumId IS NOT NULL
                    THEN CONCAT(' from ', oldgm.name, ' to ', newgm.name)
                WHEN r.oldGrowthMediumId IS NOT NULL
                    THEN CONCAT(' from ', oldgm.name)
                WHEN r.newGrowthMediumId IS NOT NULL
                    THEN CONCAT(' into ', newgm.name)
                ELSE ''
            END,
            CASE
                WHEN COALESCE(
                        NULLIF(r.repottingNotes, ''),
                        NULLIF(r.repotReasonNotes, ''),
                        NULLIF(r.newMediumNotes, ''),
                        NULLIF(r.oldMediumNotes, '')
                     ) IS NOT NULL
                    THEN CONCAT(
                        ' - ',
                        COALESCE(
                            NULLIF(r.repottingNotes, ''),
                            NULLIF(r.repotReasonNotes, ''),
                            NULLIF(r.newMediumNotes, ''),
                            NULLIF(r.oldMediumNotes, '')
                        )
                    )
                ELSE ''
            END
        )
    )  AS eventSummary,
    'repotting'  AS sourceTable,
    r.repottingId AS sourceId
FROM plant_identity pi
JOIN repotting r ON r.plantId = pi.plantId
LEFT JOIN growthmedium oldgm
    ON r.oldGrowthMediumId = oldgm.growthMediumId
LEFT JOIN growthmedium newgm
    ON r.newGrowthMediumId = newgm.growthMediumId
WHERE r.isActive = 1

UNION ALL

-- Flowering
SELECT
    pi.plantId,
    CAST(f.startDate AS DATETIME) AS eventDateTime,
    'Flowering'  AS eventType,
    (
        CONCAT(
            'Flowered',
            CASE
                WHEN f.startDate IS NOT NULL AND f.endDate IS NOT NULL
                    THEN CONCAT(
                        ' from ',
                        DATE_FORMAT(f.startDate, '%d-%m-%Y'),
                        ' to ',
                        DATE_FORMAT(f.endDate, '%d-%m-%Y')
                    )
                WHEN f.startDate IS NOT NULL AND f.endDate IS NULL
                    THEN CONCAT(
                        ' from ',
                        DATE_FORMAT(f.startDate, '%d-%m-%Y'),
                        ' (currently flowering)'
                    )
                ELSE ''
            END,
            CASE
                WHEN f.flowerCount IS NOT NULL AND f.spikeCount IS NOT NULL
                    THEN CONCAT(
                        ' with ',
                        IF(f.flowerCount = 1, '1 flower', CONCAT(f.flowerCount, ' flowers')),
                        ' over ',
                        IF(f.spikeCount = 1, '1 spike', CONCAT(f.spikeCount, ' spikes'))
                    )
                WHEN f.flowerCount IS NOT NULL
                    THEN CONCAT(
                        ' with ',
                        IF(f.flowerCount = 1, '1 flower', CONCAT(f.flowerCount, ' flowers'))
                    )
                WHEN f.spikeCount IS NOT NULL
                    THEN CONCAT(
                        ' over ',
                        IF(f.spikeCount = 1, '1 spike', CONCAT(f.spikeCount, ' spikes'))
                    )
                ELSE ''
            END,
            CASE
                WHEN f.floweringNotes IS NOT NULL AND f.floweringNotes <> ''
                    THEN CONCAT(' - ', f.floweringNotes)
                ELSE ''
            END
        )
    )  AS eventSummary,
    'flowering'  AS sourceTable,
    f.floweringId AS sourceId
FROM plant_identity pi
JOIN flowering f ON f.plantId = pi.plantId
WHERE f.isActive = 1

UNION ALL

-- Location change
SELECT
    pi.plantId,
    plh.startDateTime AS eventDateTime,
    'LocationChange'  AS eventType,
    (
        CONCAT(
            'Moved to ',
            l.locationName,
            ' on ',
            DATE_FORMAT(plh.startDateTime, '%d-%m-%Y'),
            CASE
                WHEN plh.endDateTime IS NOT NULL
                    THEN CONCAT(' to ', DATE_FORMAT(plh.endDateTime, '%d-%m-%Y'))
                ELSE ' (current)'
            END,
            CASE
                WHEN plh.moveReasonNotes IS NOT NULL AND plh.moveReasonNotes <> ''
                    THEN CONCAT(' : ', plh.moveReasonNotes)
                ELSE ''
            END,
            CASE
                WHEN plh.plantLocationNotes IS NOT NULL AND plh.plantLocationNotes <> ''
                    THEN CONCAT(' - ', plh.plantLocationNotes)
                ELSE ''
            END
        )
    )  AS eventSummary,
    'plantlocationhistory'  AS sourceTable,
    plh.plantLocationHistoryId AS sourceId
FROM plant_identity pi
JOIN plantlocationhistory plh ON plh.plantId = pi.plantId
JOIN location l ON l.locationId = plh.locationId
WHERE plh.isActive = 1;
