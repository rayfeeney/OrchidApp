DELIMITER //
CREATE OR REPLACE PROCEDURE `__migrate_generate_planttag`(OUT pPlantTag CHAR(8))
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

        SET vChecksum = fnPlantTagChecksum(CONCAT(vPrefix, vDigit, '-', LPAD(vBlock, 3, '0')));

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
END
//
DELIMITER ;

