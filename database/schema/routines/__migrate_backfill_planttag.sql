DELIMITER //
CREATE OR REPLACE PROCEDURE `__migrate_backfill_planttag`()
BEGIN
    DECLARE vDone INT DEFAULT 0;
    DECLARE vPlantId INT;
    DECLARE vTag CHAR(8);

    DECLARE cur CURSOR FOR
        SELECT plantId
        FROM plant
        ORDER BY plantId;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET vDone = 1;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO vPlantId;

        IF vDone = 1 THEN
            LEAVE read_loop;
        END IF;

        CALL __migrate_generate_planttag(vTag);

        UPDATE plant
        SET plantTag = vTag
        WHERE plantId = vPlantId;
    END LOOP;

    CLOSE cur;
END
//
DELIMITER ;

