UPDATE environmentsensor
SET
    locationName = SUBSTRING_INDEX(sensorName, ' ', 2),
    updatedDateTime = CURRENT_TIMESTAMP
WHERE locationName IS NULL;