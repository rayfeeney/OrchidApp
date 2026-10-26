-- Read-only C11 adoption review. Results identify records for investigation, not automatic repair.
-- Run against the explicitly selected database after taking a recoverable backup.
SELECT p.plantId, p.plantTag, p.endDate,
       EXISTS (SELECT 1 FROM plantlocationhistory l WHERE l.plantId=p.plantId AND l.isActive=1 AND l.endDateTime IS NULL) AS hasOpenLocation,
       EXISTS (SELECT 1 FROM flowering f WHERE f.plantId=p.plantId AND f.isActive=1 AND f.endDate IS NULL) AS hasOpenFlowering
FROM plant p
WHERE p.endDate IS NOT NULL
  AND (EXISTS (SELECT 1 FROM plantlocationhistory l WHERE l.plantId=p.plantId AND l.isActive=1 AND l.endDateTime IS NULL)
       OR EXISTS (SELECT 1 FROM flowering f WHERE f.plantId=p.plantId AND f.isActive=1 AND f.endDate IS NULL))
ORDER BY p.plantId;

SELECT 'Location' AS intervalType, l.plantId, l.plantLocationHistoryId AS intervalId,
       l.startDateTime AS startsAt, l.endDateTime AS endsAt
FROM plantlocationhistory l
WHERE l.isActive=1 AND l.endDateTime IS NOT NULL AND l.endDateTime<=l.startDateTime
UNION ALL
SELECT 'Flowering', f.plantId, f.floweringId, f.startDate, f.endDate
FROM flowering f
WHERE f.isActive=1 AND f.endDate IS NOT NULL AND f.endDate<f.startDate
ORDER BY plantId, intervalType, intervalId;
