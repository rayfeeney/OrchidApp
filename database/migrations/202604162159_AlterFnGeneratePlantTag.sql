DROP FUNCTION IF EXISTS fnGeneratePlantTag;

DELIMITER //

CREATE FUNCTION fnGeneratePlantTag()
RETURNS CHAR(8)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE vEntropy CHAR(64);
    DECLARE vPrefix VARCHAR(2);
    DECLARE vDigit INT;
    DECLARE vBlock INT;
    DECLARE vChecksum INT;
    DECLARE vCandidate CHAR(8);
    DECLARE vPrefixCount INT;
    DECLARE vOffset INT;
    DECLARE vAttempts INT DEFAULT 0;

    SELECT COUNT(*) INTO vPrefixCount
    FROM phoneticprefix
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

        SELECT prefix INTO vPrefix
        FROM phoneticprefix
        WHERE isActive = 1
        ORDER BY prefix
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
            RETURN vCandidate;
        END IF;

    END LOOP;

END //

DELIMITER ;