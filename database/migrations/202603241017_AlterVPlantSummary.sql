CREATE OR REPLACE VIEW vPlantStatus AS
SELECT
    p.plantId,
    p.acquisitionDate,
    p.acquisitionSource,
    p.plantTag,

    TRIM(
        CASE
            WHEN t.isSystemManaged = 1 THEN CONCAT(g.genusName, ' sp.')
            WHEN t.speciesName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.speciesName)
            WHEN t.hybridName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.hybridName)
            ELSE g.genusName
        END
    ) AS displayName,

    t.isActive AS taxonIsActive,
    g.isActive AS genusIsActive,

    l.locationName,

    lf.startDate AS lastFloweringDate,

    lr.repotDate AS lastRepotDate,
    gm.name AS currentGrowthMediumName,

    lfeed.eventDateTime AS lastFeedDateTime,
    ot.displayName AS lastFeedTypeDisplayName

FROM plant p
LEFT JOIN taxon t ON t.taxonId = p.taxonId
LEFT JOIN genus g ON g.genusId = t.genusId

LEFT JOIN plantlocationhistory clh
    ON clh.plantLocationHistoryId = (
        SELECT plh.plantLocationHistoryId
        FROM plantlocationhistory plh
        WHERE plh.plantId = p.plantId
          AND plh.isActive = 1
        ORDER BY plh.startDateTime DESC
        LIMIT 1
    )
LEFT JOIN location l ON l.locationId = clh.locationId

LEFT JOIN flowering lf
    ON lf.floweringId = (
        SELECT f.floweringId
        FROM flowering f
        WHERE f.plantId = p.plantId
          AND f.isActive = 1
        ORDER BY f.startDate DESC
        LIMIT 1
    )

LEFT JOIN repotting lr
    ON lr.repottingId = (
        SELECT r.repottingId
        FROM repotting r
        WHERE r.plantId = p.plantId
          AND r.isActive = 1
        ORDER BY r.repotDate DESC
        LIMIT 1
    )
LEFT JOIN growthmedium gm ON gm.growthMediumId = lr.newGrowthMediumId

LEFT JOIN plantevent lfeed
    ON lfeed.plantEventId = (
        SELECT pe.plantEventId
        FROM plantevent pe
        INNER JOIN observationtype o
            ON o.Id = pe.observationTypeId
           AND o.isActive = 1
           AND o.typeCode LIKE 'OBS_FEED%'
        WHERE pe.plantId = p.plantId
          AND pe.isActive = 1
        ORDER BY pe.eventDateTime DESC
        LIMIT 1
    )
LEFT JOIN observationtype ot ON ot.Id = lfeed.observationTypeId

WHERE p.isActive = 1
  AND p.endDate IS NULL;