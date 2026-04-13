DELIMITER //
CREATE OR REPLACE PROCEDURE `spGetPlantLineage`(
    IN pPlantId INT
)
BEGIN

    WITH RECURSIVE lineage AS (

        
        SELECT 
            p.plantId,
            p.plantTag,
            p.acquisitionDate,
            p.endDate,
            0 AS level
        FROM plant p
        WHERE p.plantId = pPlantId

        UNION ALL

        
        SELECT 
            parent.plantId,
            parent.plantTag,
            parent.acquisitionDate,
            parent.endDate,
            l.level - 1
        FROM lineage l
        JOIN plantsplitchild psc 
            ON psc.childPlantId = l.plantId
        JOIN plantsplit ps 
            ON ps.plantSplitId = psc.plantSplitId
        JOIN plant parent 
            ON parent.plantId = ps.parentPlantId

        
        WHERE l.level > -20
    )

    SELECT 
        plantId,
        plantTag,
        acquisitionDate,
        endDate,
        level
    FROM lineage
    ORDER BY level DESC;   

END
//
DELIMITER ;

