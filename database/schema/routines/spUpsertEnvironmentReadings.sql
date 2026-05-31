SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spUpsertEnvironmentReadings`()
BEGIN
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
END
//

DELIMITER ;
