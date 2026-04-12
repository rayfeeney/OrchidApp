SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW vplantsplitchildren AS
SELECT
    ps.parentPlantId,
    child.plantId AS childPlantId,
    child.plantTag,
    child.acquisitionDate
FROM orchids.plantsplit ps
JOIN orchids.plantsplitchild psc 
    ON psc.plantSplitId = ps.plantSplitId
JOIN orchids.plant child 
    ON child.plantId = psc.childPlantId;