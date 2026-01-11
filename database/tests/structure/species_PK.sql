-- species_PK.sql
START TRANSACTION;

INSERT INTO orchids.species (speciesId, genus, isActive)
VALUES (1, 'Phalaenopsis', 1);

-- Optional sanity check -- only 1 row
SELECT speciesId, genus
FROM orchids.species; 

ROLLBACK;

START TRANSACTION;

-- This must fail
INSERT INTO orchids.species (speciesId, genus, isActive)
VALUES (1, 'Cattleya', 1);

-- Optional sanity check -- no new row
SELECT speciesId, genus
FROM orchids.species;

ROLLBACK;
