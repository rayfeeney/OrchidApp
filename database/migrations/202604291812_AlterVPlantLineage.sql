CREATE OR REPLACE VIEW vplantlineage AS

-- Split
SELECT
    c.childPlantId,
    s.parentPlantId,
    'Split' AS relationshipType
FROM plantsplitchild c
JOIN plantsplit s ON c.plantSplitId = s.plantSplitId
WHERE c.isActive = 1

UNION ALL

-- Propagation
SELECT
    p.childPlantId,
    p.parentPlantId,
    pt.propagationTypeName AS relationshipType
FROM plantpropagation p
JOIN propagationtype pt 
    ON pt.propagationTypeId = p.propagationTypeId
WHERE p.isActive = 1;