-- Step 1: drop existing FKs
ALTER TABLE plantphoto
  DROP FOREIGN KEY fk_plantphoto_plant,
  DROP FOREIGN KEY fk_plantphoto_plantevent;

-- Step 2: drop supporting indexes
ALTER TABLE plantphoto
  DROP INDEX fk_plantphoto_plant,
  DROP INDEX fk_plantphoto_plantevent;

-- Step 3: recreate FKs with correct naming + behaviour
ALTER TABLE plantphoto
  ADD CONSTRAINT fkPlantPhotoPlant
  FOREIGN KEY (plantId)
  REFERENCES plant(plantId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT,

  ADD CONSTRAINT fkPlantPhotoPlantEvent
  FOREIGN KEY (plantEventId)
  REFERENCES plantevent(plantEventId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;