SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW vplantcurrentlocation AS
SELECT
    plh.plantLocationHistoryId AS plantLocationHistoryId,
    plant.plantId,
    loc.locationId,
    loc.locationName,
    loc.locationTypeCode,
    plh.startDateTime AS locationStartDateTime,
    plant.plantTag,
    plant.plantName,
    taxon.taxonId,
    genus.genusName,
    genus.isActive AS genusIsActive,
    CASE
        WHEN taxon.isSystemManaged = 1 THEN CONCAT(genus.genusName, ' sp.')
        WHEN taxon.speciesName IS NOT NULL THEN CONCAT(genus.genusName, ' ', taxon.speciesName)
        WHEN taxon.hybridName IS NOT NULL THEN CONCAT(genus.genusName, ' ', taxon.hybridName)
        ELSE genus.genusName
    END AS displayName,
    plant.endDate AS plantEndDate,
    plh.RowOrder
FROM plant
JOIN taxon ON taxon.taxonId = plant.taxonId
JOIN genus ON genus.genusId = taxon.genusId
LEFT JOIN (
    SELECT sub.*
    FROM (
        SELECT lochistory.*,
               ROW_NUMBER() OVER (PARTITION BY lochistory.plantId ORDER BY lochistory.startDateTime DESC) AS RowOrder
        FROM plantlocationhistory lochistory
        WHERE lochistory.isActive = 1
    ) sub
    WHERE sub.RowOrder = 1
) plh ON plant.plantId = plh.plantId
LEFT JOIN location loc ON loc.locationId = plh.locationId AND loc.isActive = 1
WHERE plant.isActive = 1;
