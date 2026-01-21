START TRANSACTION;

-- Baseline insert
INSERT INTO orchids.location (locationName)
VALUES ('Test Location');

-- Verify defaults
SELECT
  locationId,
  locationName,
  isActive,
  createdDateTime,
  updatedDateTime
FROM orchids.location
ORDER BY locationId DESC;

ROLLBACK;
