CREATE OR REPLACE VIEW vplantcurrentgrowthmedium AS
SELECT
    r.plantId
    ,r.newGrowthMediumId AS growthMediumId
    ,gm.name AS growthMediumName
    ,r.potSize
    ,r.repottingNotes
    ,r.repotDate
FROM (
    SELECT
        repottingId,
        plantId,
        newGrowthMediumId,
        potSize,
        repottingNotes,
        repotDate,
        ROW_NUMBER() OVER (
            PARTITION BY plantId
            ORDER BY repotDate DESC, repottingId DESC
        ) AS rn
    FROM repotting
    WHERE isActive = 1
) r
LEFT JOIN growthmedium gm
    ON gm.growthMediumId = r.newGrowthMediumId
WHERE r.rn = 1;