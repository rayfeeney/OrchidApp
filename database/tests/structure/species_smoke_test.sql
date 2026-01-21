START TRANSACTION;

-- Genus only
INSERT INTO orchids.species (genus)
VALUES ('Phalaenopsis');

-- Genus + species
INSERT INTO orchids.species (genus, speciesName)
VALUES ('Cattleya', 'labiata');

-- Genus + hybrid
INSERT INTO orchids.species (genus, hybridName)
VALUES ('Oncidium', 'Sharry Baby');

-- Verify records
SELECT
  speciesId,
  genus,
  speciesName,
  hybridName
FROM orchids.species
ORDER BY speciesId;

-- Invalid combinations (negative test) - MUST FAIL
INSERT INTO orchids.species (genus, speciesName, hybridName)
VALUES ('Invalid', 'Species', 'Hybrid');

-- Verify not inserted
SELECT
  speciesId,
  genus,
  speciesName,
  hybridName
FROM orchids.species
ORDER BY speciesId;

ROLLBACK;
