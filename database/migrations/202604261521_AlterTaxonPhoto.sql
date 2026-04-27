-- Step 1: drop FK
ALTER TABLE taxonphoto
  DROP FOREIGN KEY fk_taxonphoto_taxon;

-- Step 2: drop supporting index
ALTER TABLE taxonphoto
  DROP INDEX fk_taxonphoto_taxon;

-- Step 3: recreate FK with correct naming + behaviour
ALTER TABLE taxonphoto
  ADD CONSTRAINT fkTaxonPhotoTaxon
  FOREIGN KEY (taxonId)
  REFERENCES taxon(taxonId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;