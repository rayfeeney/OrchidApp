CREATE OR REPLACE VIEW vplantcurrentlyflowering AS

SELECT
    p.plantId,
    p.plantTag,
    l.locationName,
    g.genusId,
    g.genusName,
    CASE 
        WHEN t.isSystemManaged = 1 THEN CONCAT(g.genusName, ' sp.')
        WHEN t.speciesName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.speciesName)
        WHEN t.hybridName IS NOT NULL THEN CONCAT(g.genusName, ' ', t.hybridName)
        ELSE g.genusName
    END AS displayName,
    f.startDate AS floweringStartDate

FROM 
    plant p

    INNER JOIN taxon t
        ON t.taxonId = p.taxonId

    INNER JOIN genus g
        ON g.genusId = t.genusId

    INNER JOIN flowering f
        ON f.plantId = p.plantId
        AND f.isActive = 1
        AND f.endDate IS NULL

    LEFT JOIN plantlocationhistory plh
        ON plh.plantId = p.plantId
        AND plh.isActive = 1
        AND plh.endDateTime IS NULL

    LEFT JOIN location l
        ON l.locationId = plh.locationId

WHERE 
    p.endDate IS NULL;