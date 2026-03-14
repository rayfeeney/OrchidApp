SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW vplantactivecurrentlocation AS
SELECT
    p.plantId,
    t.taxonId,
    p.plantTag,
    p.plantName,
    g.genusName,
    g.isActive AS genusIsActive,
    loc.locationId,
    loc.locationName,
    loc.locationTypeCode,
    plh.startDateTime AS locationStartDateTime,
    CASE
        WHEN t.isSystemManaged = 1 THEN CONCAT(g.genusName, ' sp.')
        WHEN t.speciesName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.speciesName)
        WHEN t.hybridName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.hybridName)
        ELSE g.genusName
    END AS displayName,
    pp.filePath AS heroFilePath
FROM plant p
JOIN taxon t ON t.taxonId = p.taxonId
JOIN genus g ON g.genusId = t.genusId
LEFT JOIN (
    SELECT sub.plantId, sub.locationId, sub.startDateTime
    FROM (
        SELECT lochistory.plantId,
               lochistory.locationId,
               lochistory.startDateTime,
               ROW_NUMBER() OVER (PARTITION BY lochistory.plantId ORDER BY lochistory.startDateTime DESC) AS RowOrder
        FROM plantlocationhistory lochistory
        WHERE lochistory.isActive = 1
    ) sub
    WHERE sub.RowOrder = 1
) plh ON p.plantId = plh.plantId
LEFT JOIN location loc ON loc.locationId = plh.locationId AND loc.isActive = 1
LEFT JOIN plantphoto pp ON pp.plantId = p.plantId AND pp.isHero = 1 AND pp.isActive = 1
WHERE p.isActive = 1
  AND p.endDate IS NULL;
