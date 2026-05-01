CREATE OR REPLACE VIEW vplantsincelastflowered AS

SELECT
    p.plantId,
    p.plantTag,
    p.acquisitionDate,

    l.locationName,

    g.genusId,
    g.genusName,

    CASE 
        WHEN t.isSystemManaged = 1 THEN CONCAT(g.genusName, ' sp.')
        WHEN t.speciesName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.speciesName)
        WHEN t.hybridName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.hybridName)
        ELSE g.genusName
    END AS displayName,

    lastflower.lastFlowerEndDate,

    TIMESTAMPDIFF(
        MONTH,
        lastflower.lastFlowerEndDate,
        CURDATE()
    ) AS monthsSinceFlower

FROM plant p

INNER JOIN taxon t
    ON t.taxonId = p.taxonId

INNER JOIN genus g
    ON g.genusId = t.genusId

-- last completed flowering
LEFT JOIN (
    SELECT
        f.plantId,
        MAX(f.endDate) AS lastFlowerEndDate
    FROM flowering f
    WHERE
        f.isActive = 1
        AND f.endDate IS NOT NULL
    GROUP BY f.plantId
) lastflower
    ON lastflower.plantId = p.plantId

-- current location
LEFT JOIN plantlocationhistory plh
    ON plh.plantId = p.plantId
    AND plh.isActive = 1
    AND plh.endDateTime IS NULL

LEFT JOIN location l
    ON l.locationId = plh.locationId

WHERE
    p.endDate IS NULL

    -- exclude currently flowering
    AND NOT EXISTS (
        SELECT 1
        FROM flowering f2
        WHERE
            f2.plantId = p.plantId
            AND f2.isActive = 1
            AND f2.endDate IS NULL
    );