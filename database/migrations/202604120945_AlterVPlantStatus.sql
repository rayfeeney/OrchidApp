SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP VIEW IF EXISTS orchids.vPlantStatus;

CREATE OR REPLACE VIEW orchids.vplantstatus AS
SELECT 
    p.plantId AS plantId,
    p.acquisitionDate AS acquisitionDate,
    p.acquisitionSource AS acquisitionSource,
    p.endDate AS endDate,
    p.plantTag AS plantTag,
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
    l.locationName AS locationName,
    lf.startDate AS lastFloweringDate,
    lr.repotDate AS lastRepotDate,
    gm.name AS currentGrowthMediumName,
    lfeed.eventDateTime AS lastFeedDateTime,
    ot.displayName AS lastFeedTypeDisplayName,
    CASE
		WHEN psc.plantSplitChildId IS NOT NULL THEN 1
        ELSE 0
	END AS hasParent,
    ps.parentPlantId,
    parent.plantTag AS parentPlantTag,
    CASE
		WHEN children.plantSplitId IS NOT NULL THEN 1
        ELSE 0
	END AS hasChildren
FROM orchids.plant p
LEFT JOIN orchids.taxon t 
    ON t.taxonId = p.taxonId
LEFT JOIN orchids.genus g 
    ON g.genusId = t.genusId
LEFT JOIN orchids.plantlocationhistory clh 
    ON clh.plantLocationHistoryId = (
        SELECT plh.plantLocationHistoryId
        FROM orchids.plantlocationhistory plh
        WHERE plh.plantId = p.plantId
          AND plh.isActive = 1
        ORDER BY plh.startDateTime DESC
        LIMIT 1
    )
LEFT JOIN orchids.location l 
    ON l.locationId = clh.locationId
LEFT JOIN orchids.flowering lf 
    ON lf.floweringId = (
        SELECT f.floweringId
        FROM orchids.flowering f
        WHERE f.plantId = p.plantId
          AND f.isActive = 1
        ORDER BY f.startDate DESC
        LIMIT 1
    )
LEFT JOIN orchids.repotting lr 
    ON lr.repottingId = (
        SELECT r.repottingId
        FROM orchids.repotting r
        WHERE r.plantId = p.plantId
          AND r.isActive = 1
        ORDER BY r.repotDate DESC
        LIMIT 1
    )
LEFT JOIN orchids.growthmedium gm 
    ON gm.growthMediumId = lr.newGrowthMediumId
LEFT JOIN orchids.plantevent lfeed 
    ON lfeed.plantEventId = (
        SELECT pe.plantEventId
        FROM orchids.plantevent pe
        JOIN orchids.observationtype o 
            ON o.Id = pe.observationTypeId
           AND o.isActive = 1
           AND o.typeCode LIKE 'OBS_FEED%'
        WHERE pe.plantId = p.plantId
          AND pe.isActive = 1
        ORDER BY pe.eventDateTime DESC
        LIMIT 1
    )
LEFT JOIN orchids.observationtype ot 
    ON ot.Id = lfeed.observationTypeId
LEFT JOIN orchids.plantsplitchild psc
	ON p.plantId = psc.childPlantId
LEFT JOIN orchids.plantsplit ps
	ON psc.plantSplitId = ps.plantSplitId
LEFT JOIN orchids.plant parent
	ON ps.parentPlantId = parent.plantId
LEFT JOIN orchids.plantsplit children
	ON p.plantId = children.parentPlantId
WHERE p.isActive = 1;