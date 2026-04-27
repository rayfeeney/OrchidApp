-- Step 1: drop incorrectly named index (will be replaced by FK-owned index)
ALTER TABLE plantsplitchild
  DROP INDEX ixPlantSplitChild_splitId;

-- Step 2: add foreign keys (this will create correctly named indexes)

ALTER TABLE plantsplitchild
  ADD CONSTRAINT fkPlantSplitChildPlant
  FOREIGN KEY (childPlantId)
  REFERENCES plant(plantId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT,

  ADD CONSTRAINT fkPlantSplitChildSplit
  FOREIGN KEY (plantSplitId)
  REFERENCES plantsplit(plantSplitId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;