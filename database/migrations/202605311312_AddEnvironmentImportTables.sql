CREATE TABLE environmentimportfile (
    environmentImportFileId BIGINT NOT NULL AUTO_INCREMENT,
    fileName VARCHAR(500) NOT NULL,
    filePath VARCHAR(1000) NOT NULL,
    fileHash CHAR(64) NOT NULL,
    fileSensorName VARCHAR(255) NOT NULL,
    fileTimestampText VARCHAR(12) NULL,
    firstReadingDateTime DATETIME NULL,
    lastReadingDateTime DATETIME NULL,
    rowCount INT NOT NULL DEFAULT 0,
    insertedRowCount INT NULL,
    updatedRowCount INT NULL,
    unchangedRowCount INT NULL,
    status VARCHAR(50) NOT NULL,
    errorMessage TEXT NULL,
    importStartedAt DATETIME NOT NULL,
    importCompletedAt DATETIME NULL,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (environmentImportFileId),

    INDEX ixEnvironmentImportFile_FileName (fileName),
    INDEX ixEnvironmentImportFile_FileSensorName (fileSensorName),
    INDEX ixEnvironmentImportFile_FileHash (fileHash),
    INDEX ixEnvironmentImportFile_Status (status),
    INDEX ixEnvironmentImportFile_FirstReadingDateTime (firstReadingDateTime),
    INDEX ixEnvironmentImportFile_LastReadingDateTime (lastReadingDateTime)
);

CREATE TABLE environmentimportrow (
    environmentImportFileId BIGINT NOT NULL,
    sourceRowNumber INT NOT NULL,
    rawTimestampText VARCHAR(100) NOT NULL,
    rawTemperatureText VARCHAR(100) NULL,
    rawHumidityText VARCHAR(100) NULL,
    readingDateTime DATETIME NOT NULL,
    temperatureCelsius DECIMAL(6,2) NOT NULL,
    relativeHumidity DECIMAL(6,2) NOT NULL,

    PRIMARY KEY (environmentImportFileId, sourceRowNumber),

    INDEX ixEnvironmentImportRow_ReadingDateTime (readingDateTime)
);

CREATE TABLE environmentreading (
    environmentReadingId BIGINT NOT NULL AUTO_INCREMENT,
    sensorName VARCHAR(255) NOT NULL,
    readingDateTime DATETIME NOT NULL,
    temperatureCelsius DECIMAL(6,2) NOT NULL,
    relativeHumidity DECIMAL(6,2) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME NULL,

    PRIMARY KEY (environmentReadingId),

    UNIQUE KEY uqEnvironmentReading_SensorName_ReadingDateTime (
        sensorName,
        readingDateTime
    ),

    INDEX ixEnvironmentReading_SensorName (sensorName),
    INDEX ixEnvironmentReading_ReadingDateTime (readingDateTime)
);