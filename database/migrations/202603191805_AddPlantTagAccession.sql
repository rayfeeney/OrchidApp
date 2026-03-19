DROP PROCEDURE IF EXISTS spBackfillPlantTags;

DELIMITER //

CREATE PROCEDURE spBackfillPlantTags()
BEGIN
    DECLARE vDone INT DEFAULT 0;
    DECLARE vPlantId INT;
    DECLARE vTag CHAR(8);

    DECLARE cur CURSOR FOR
        SELECT plantId
        FROM plant
        ORDER BY plantId;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET vDone = 1;

    START TRANSACTION;

    OPEN cur;

    read_loop: LOOP

        FETCH cur INTO vPlantId;

        IF vDone = 1 THEN
            LEAVE read_loop;
        END IF;

        SELECT plantTag INTO vTag
        FROM (CALL spGeneratePlantTag()) AS t;

        UPDATE plant
        SET plantTag = vTag
        WHERE plantId = vPlantId;

    END LOOP;

    CLOSE cur;

    COMMIT;

END //

DELIMITER ;