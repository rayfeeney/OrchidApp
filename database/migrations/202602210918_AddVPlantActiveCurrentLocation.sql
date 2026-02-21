USE orchids;

DROP VIEW IF EXISTS vplantactivecurrentlocation;

CREATE OR REPLACE
SQL SECURITY INVOKER
VIEW orchids.vplantactivecurrentlocation AS

SELECT
    p.plantId                                   AS plantId,
    t.taxonId                                   AS taxonId,
    p.plantTag                                  AS plantTag,
    p.plantName                                 AS plantName,
    loc.locationId                              AS locationId,
    loc.locationName                            AS locationName,
    loc.locationTypeCode                        AS locationTypeCode,
    plh.startDateTime                           AS locationStartDateTime,
    CASE 
        WHEN (t.`isSystemManaged` = 1)
            THEN CONCAT (
                    g.`genusName`
                    ,' sp.'
                    )
        WHEN (t.`speciesName` IS NOT NULL)
            THEN CONCAT (
                    g.`genusName`
                    ,' '
                    ,t.`speciesName`
                    )
        WHEN (t.`hybridName` IS NOT NULL)
            THEN CONCAT (
                    g.`genusName`
                    ,' '
                    ,t.`hybridName`
                    )
        ELSE g.`genusName`
        END AS displayName,
    pp.fileName                                 AS photoFileName

FROM 
    orchids.plant p
    JOIN orchids.taxon t
        ON t.taxonId = p.taxonId
    JOIN orchids.genus g
        ON g.genusId = t.genusId
    LEFT JOIN (
                SELECT 
                    *
                FROM 
                    (
                    SELECT
                        lochistory.plantId,
                        lochistory.locationId,
                        lochistory.startDateTime,
                        ROW_NUMBER() OVER (
                            PARTITION BY lochistory.plantId
                            ORDER BY lochistory.startDateTime DESC
                        ) AS RowOrder
                    
                    FROM 
                        orchids.plantlocationhistory lochistory
                    
                    WHERE 
                        lochistory.isActive = 1
                    ) sub
                WHERE 
                    sub.RowOrder = 1
    ) plh
        ON p.plantId = plh.plantId
    LEFT JOIN orchids.location loc
        ON loc.locationId = plh.locationId
        AND loc.isActive = 1
    LEFT JOIN orchids.plantphoto pp
        ON pp.plantId = p.plantId
        AND pp.isHero = 1
        AND pp.isActive = 1

WHERE
    p.isActive = 1
    AND p.endDate IS NULL;