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
    'Observation' COLLATE utf8mb4_unicode_ci AS eventType,
    pe.eventDetails COLLATE utf8mb4_unicode_ci AS eventSummary,
    'plantevent' COLLATE utf8mb4_unicode_ci AS sourceTable,
    pe.plantEventId AS sourceId
FROM plant_identity pi
JOIN plantevent pe ON pe.plantId = pi.plantId
WHERE pe.isActive = 1

UNION ALL

-- Repotting
SELECT
    pi.plantId,
    CAST(r.repotDate AS DATETIME) AS eventDateTime,
    'Repotting' COLLATE utf8mb4_unicode_ci AS eventType,
    (
        CONCAT(
            'Repotted',
            CASE
                WHEN r.oldMediumCode IS NOT NULL AND r.newMediumCode IS NOT NULL
                    THEN CONCAT(' from ', r.oldMediumCode, ' to ', r.newMediumCode)
                WHEN r.oldMediumCode IS NOT NULL
                    THEN CONCAT(' from ', r.oldMediumCode)
                WHEN r.newMediumCode IS NOT NULL
                    THEN CONCAT(' into ', r.newMediumCode)
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
    ) COLLATE utf8mb4_unicode_ci AS eventSummary,
    'repotting' COLLATE utf8mb4_unicode_ci AS sourceTable,
    r.repottingId AS sourceId
FROM plant_identity pi
JOIN repotting r ON r.plantId = pi.plantId
WHERE r.isActive = 1

UNION ALL

-- Flowering
SELECT
    pi.plantId,
    CAST(f.startDate AS DATETIME) AS eventDateTime,
    'Flowering' COLLATE utf8mb4_unicode_ci AS eventType,
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
    ) COLLATE utf8mb4_unicode_ci AS eventSummary,
    'flowering' COLLATE utf8mb4_unicode_ci AS sourceTable,
    f.floweringId AS sourceId
FROM plant_identity pi
JOIN flowering f ON f.plantId = pi.plantId
WHERE f.isActive = 1

UNION ALL

-- Location change
SELECT
    pi.plantId,
    plh.startDateTime AS eventDateTime,
    'LocationChange' COLLATE utf8mb4_unicode_ci AS eventType,
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
    ) COLLATE utf8mb4_unicode_ci AS eventSummary,
    'plantlocationhistory' COLLATE utf8mb4_unicode_ci AS sourceTable,
    plh.plantLocationHistoryId AS sourceId
FROM plant_identity pi
JOIN plantlocationhistory plh ON plh.plantId = pi.plantId
JOIN location l ON l.locationId = plh.locationId
WHERE plh.isActive = 1;
