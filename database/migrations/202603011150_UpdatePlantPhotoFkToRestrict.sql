USE orchids;

-- Drop existing FK constraints (currently implicit NO ACTION)

ALTER TABLE plantphoto
    DROP FOREIGN KEY fk_plantphoto_plant,
    DROP FOREIGN KEY fk_plantphoto_plantevent;

-- Recreate with explicit RESTRICT rules

ALTER TABLE plantphoto
    ADD CONSTRAINT fk_plantphoto_plant
        FOREIGN KEY (plantId)
        REFERENCES plant (plantId)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,

    ADD CONSTRAINT fk_plantphoto_plantevent
        FOREIGN KEY (plantEventId)
        REFERENCES plantevent (plantEventId)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;