DROP PROCEDURE IF EXISTS __migrate_generate_planttag;
DROP PROCEDURE IF EXISTS __migrate_backfill_planttag;

DELIMITER //

CREATE PROCEDURE __migrate_generate_planttag(OUT pPlantTag CHAR(8))
BEGIN
    DECLARE vEntropy CHAR(64);
    DECLARE vPrefix CHAR(2);
    DECLARE vDigit INT;
    DECLARE vBlock INT;
    DECLARE vChecksum TINYINT;
    DECLARE vCandidate CHAR(8);
    DECLARE vPrefixCount INT;
    DECLARE vOffset INT;
    DECLARE vAttempts INT DEFAULT 0;

    SELECT COUNT(*) INTO vPrefixCount
    FROM PhoneticPrefix
    WHERE isActive = 1;

    IF vPrefixCount = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No active phonetic prefixes configured';
    END IF;

    generation_loop: LOOP
        SET vAttempts = vAttempts + 1;

        IF vAttempts > 1000 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Unable to generate unique plantTag after 1000 attempts';
        END IF;

        SET vEntropy = SHA2(UUID(), 256);

        SET vOffset = CONV(SUBSTRING(vEntropy, 1, 8), 16, 10) MOD vPrefixCount;

        SELECT prefix
          INTO vPrefix
          FROM PhoneticPrefix
         WHERE isActive = 1
         ORDER BY prefixId
         LIMIT vOffset, 1;

        SET vDigit = CONV(SUBSTRING(vEntropy, 9, 2), 16, 10) MOD 10;
        SET vBlock = CONV(SUBSTRING(vEntropy, 11, 8), 16, 10) MOD 1000;

        SET vChecksum = (
            (
                ASCII(SUBSTRING(vPrefix,1,1)) +
                ASCII(SUBSTRING(vPrefix,2,1)) +
                vDigit +
                FLOOR(vBlock / 100) +
                FLOOR((vBlock % 100) / 10) +
                (vBlock % 10)
            ) MOD 10
        );

        SET vCandidate = CONCAT(
            vPrefix,
            vDigit,
            '-',
            LPAD(vBlock, 3, '0'),
            vChecksum
        );

        IF NOT EXISTS (
            SELECT 1
            FROM plant
            WHERE plantTag = vCandidate
        ) THEN
            SET pPlantTag = vCandidate;
            LEAVE generation_loop;
        END IF;
    END LOOP;
END//

CREATE PROCEDURE __migrate_backfill_planttag()
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
END//

DELIMITER ;

CALL __migrate_backfill_planttag();

DROP PROCEDURE __migrate_backfill_planttag;
DROP PROCEDURE __migrate_generate_planttag;

ALTER TABLE plant
ADD CONSTRAINT uqPlantPlantTag UNIQUE (plantTag);