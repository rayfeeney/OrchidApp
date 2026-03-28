UPDATE flowering
SET startDate = CAST(startDate AS DATETIME),
    endDate = CAST(endDate AS DATETIME);

UPDATE repotting
SET repotDate = CAST(repotDate AS DATETIME);