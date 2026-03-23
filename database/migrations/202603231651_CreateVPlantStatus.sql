CREATE OR REPLACE VIEW vPlantStatus AS
SELECT 
    plant.plantId,
    plant.acquisitionDate,
    plant.plantTag,

    CASE
        WHEN taxon.isSystemManaged = 1 THEN CONCAT(genus.genusName, ' sp.')
        WHEN taxon.speciesName IS NOT NULL THEN CONCAT(genus.genusName, ' ', taxon.speciesName)
        WHEN taxon.hybridName IS NOT NULL THEN CONCAT(genus.genusName, ' ', taxon.hybridName)
        ELSE genus.genusName
    END AS displayName,

    taxon.isActive  AS taxonIsActive,
    genus.isActive  AS genusIsActive,

    loc.locationName,

    lastFlower.lastFloweringDate,
    lastRepot.lastRepotDate,
    growthMedium.name AS currentGrowthMediumName,

    lastFeed.lastFeedDateTime,
    lastFeed.lastFeedTypeDisplayName

FROM orchids.plant plant

LEFT JOIN orchids.taxon taxon
    ON plant.taxonId = taxon.taxonId

LEFT JOIN orchids.genus genus
    ON taxon.genusId = genus.genusId

LEFT JOIN (
    SELECT plantId, locationId
    FROM (
        SELECT
            lochistory.plantId,
            lochistory.locationId,
            ROW_NUMBER() OVER (
                PARTITION BY lochistory.plantId
                ORDER BY lochistory.startDateTime DESC
            ) AS rn
        FROM orchids.plantlocationhistory lochistory
        WHERE lochistory.isActive = 1
    ) ordered
    WHERE rn = 1
) currentLocation
    ON plant.plantId = currentLocation.plantId

LEFT JOIN orchids.location loc
    ON loc.locationId = currentLocation.locationId

LEFT JOIN (
    SELECT plantId, startDate AS lastFloweringDate
    FROM (
        SELECT
            flowering.plantId,
            flowering.startDate,
            ROW_NUMBER() OVER (
                PARTITION BY flowering.plantId
                ORDER BY flowering.startDate DESC
            ) AS rn
        FROM orchids.flowering flowering
        WHERE flowering.isActive = 1
    ) ordered
    WHERE rn = 1
) lastFlower
    ON plant.plantId = lastFlower.plantId

LEFT JOIN (
    SELECT plantId, repotDate AS lastRepotDate, newGrowthMediumId
    FROM (
        SELECT
            repotting.plantId,
            repotting.repotDate,
            repotting.newGrowthMediumId,
            ROW_NUMBER() OVER (
                PARTITION BY repotting.plantId
                ORDER BY repotting.repotDate DESC
            ) AS rn
        FROM orchids.repotting repotting
        WHERE repotting.isActive = 1
    ) ordered
    WHERE rn = 1
) lastRepot
    ON plant.plantId = lastRepot.plantId

LEFT JOIN orchids.growthMedium growthMedium
    ON growthMedium.growthMediumId = lastRepot.newGrowthMediumId

LEFT JOIN (
    SELECT plantId, eventDateTime AS lastFeedDateTime, displayName AS lastFeedTypeDisplayName
    FROM (
        SELECT
            eventOrder.plantId,
            eventOrder.eventDateTime,
            obstype.displayName,
            ROW_NUMBER() OVER (
                PARTITION BY eventOrder.plantId
                ORDER BY eventOrder.eventDateTime DESC
            ) AS rn
        FROM orchids.plantevent eventOrder
        INNER JOIN orchids.observationtype obstype
            ON obstype.Id = eventOrder.observationTypeId
           AND obstype.isActive = 1
        WHERE eventOrder.isActive = 1
          AND obstype.typeCode LIKE 'OBS_FEED%'
    ) ordered
    WHERE rn = 1
) lastFeed
    ON plant.plantId = lastFeed.plantId

WHERE plant.endDate IS NULL
  AND plant.isActive = 1;