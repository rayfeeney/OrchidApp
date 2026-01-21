-- location_PK.sql
START TRANSACTION;

INSERT INTO orchids.location (locationName, isActive)
VALUES ('Garden', 1);

INSERT INTO orchids.location (locationName, isActive)
VALUES ('Front bedroom', 0);

-- Optional sanity check -- only 1 row
SELECT *
FROM orchids.location; 

ROLLBACK;

