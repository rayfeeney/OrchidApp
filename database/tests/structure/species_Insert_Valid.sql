-- species_Insert_Valid.sql
START TRANSACTION;

INSERT INTO orchids.species (genus, isActive)
VALUES ('Phalaenopsis', 1);

INSERT INTO orchids.species (genus, isActive)
VALUES ('Cattleya', 1);

-- Optional sanity check
SELECT speciesId, genus
FROM orchids.species;

ROLLBACK;
