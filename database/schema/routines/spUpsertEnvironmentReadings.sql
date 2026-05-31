SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spUpsertEnvironmentReadings`(
    IN pEnvironmentImportFileId BIGINT
)
BEGIN
    DECLARE vInsertedRowCount INT DEFAULT 0;
    DECLARE vUpdatedRowCount INT DEFAULT 0;
    DECLARE vUnchangedRowCount INT DEFAULT 0;

    SELECT COUNT(*)
    INTO vInsertedRowCount
    FROM environmentimportrow importRow
    INNER JOIN environmentimportfile importFile
        ON importFile.environmentImportFileId = importRow.environmentImportFileId
    LEFT JOIN environmentreading reading
        ON reading.sensorName = importFile.fileSensorName
        AND reading.readingDateTime = importRow.readingDateTime
    WHERE importRow.environmentImportFileId = pEnvironmentImportFileId
        AND reading.environmentReadingId IS NULL;

    SELECT COUNT(*)
    INTO vUpdatedRowCount
    FROM environmentimportrow importRow
    INNER JOIN environmentimportfile importFile
        ON importFile.environmentImportFileId = importRow.environmentImportFileId
    INNER JOIN environmentreading reading
        ON reading.sensorName = importFile.fileSensorName
        AND reading.readingDateTime = importRow.readingDateTime
    WHERE importRow.environmentImportFileId = pEnvironmentImportFileId
        AND NOT (
            reading.temperatureCelsius <=> importRow.temperatureCelsius
            AND reading.relativeHumidity <=> importRow.relativeHumidity
        );

    SELECT COUNT(*)
    INTO vUnchangedRowCount
    FROM environmentimportrow importRow
    INNER JOIN environmentimportfile importFile
        ON importFile.environmentImportFileId = importRow.environmentImportFileId
    INNER JOIN environmentreading reading
        ON reading.sensorName = importFile.fileSensorName
        AND reading.readingDateTime = importRow.readingDateTime
    WHERE importRow.environmentImportFileId = pEnvironmentImportFileId
        AND reading.temperatureCelsius <=> importRow.temperatureCelsius
        AND reading.relativeHumidity <=> importRow.relativeHumidity;

    INSERT INTO environmentreading (
        sensorName,
        readingDateTime,
        temperatureCelsius,
        relativeHumidity,
        createdAt,
        updatedAt
    )
    SELECT
        importFile.fileSensorName,
        importRow.readingDateTime,
        importRow.temperatureCelsius,
        importRow.relativeHumidity,
        NOW(),
        NULL
    FROM environmentimportrow importRow
    INNER JOIN environmentimportfile importFile
        ON importFile.environmentImportFileId = importRow.environmentImportFileId
    WHERE importRow.environmentImportFileId = pEnvironmentImportFileId
    ON DUPLICATE KEY UPDATE
        updatedAt = CASE
            WHEN NOT (
                environmentreading.temperatureCelsius <=> VALUES(temperatureCelsius)
                AND environmentreading.relativeHumidity <=> VALUES(relativeHumidity)
            )
            THEN NOW()
            ELSE environmentreading.updatedAt
        END,
        temperatureCelsius = CASE
            WHEN NOT (
                environmentreading.temperatureCelsius <=> VALUES(temperatureCelsius)
                AND environmentreading.relativeHumidity <=> VALUES(relativeHumidity)
            )
            THEN VALUES(temperatureCelsius)
            ELSE environmentreading.temperatureCelsius
        END,
        relativeHumidity = CASE
            WHEN NOT (
                environmentreading.temperatureCelsius <=> VALUES(temperatureCelsius)
                AND environmentreading.relativeHumidity <=> VALUES(relativeHumidity)
            )
            THEN VALUES(relativeHumidity)
            ELSE environmentreading.relativeHumidity
        END;

    UPDATE environmentimportfile
    SET
        insertedRowCount = vInsertedRowCount,
        updatedRowCount = vUpdatedRowCount,
        unchangedRowCount = vUnchangedRowCount,
        status = 'Completed',
        importCompletedAt = NOW()
    WHERE environmentImportFileId = pEnvironmentImportFileId;
END
//

DELIMITER ;
