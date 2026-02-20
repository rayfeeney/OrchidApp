ALTER TABLE orchids.plantsplit
  DROP FOREIGN KEY fkPlantSplitChild;

ALTER TABLE orchids.plantsplit
  DROP INDEX uqPlantSplitUniquePair;

ALTER TABLE orchids.plantsplit
  DROP INDEX ixPlantSplitChild;
