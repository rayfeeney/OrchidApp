USE orchids;

CREATE OR REPLACE 
VIEW vLocationActiveList
AS
SELECT
    locationId,
    locationName,
    locationTypeCode,
    climateCode
FROM location
WHERE isActive = 1;