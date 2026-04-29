CREATE OR REPLACE VIEW vplantlineage AS

-- Split relationships
SELECT
    c.childPlantId,
    s.parentPlantId
FROM plantsplitchild c
JOIN plantsplit s 
    ON c.plantSplitId = s.plantSplitId
WHERE c.isActive = 1

UNION ALL

-- Propagation relationships
SELECT
    p.childPlantId,
    p.parentPlantId
FROM plantpropagation p
WHERE p.isActive = 1;