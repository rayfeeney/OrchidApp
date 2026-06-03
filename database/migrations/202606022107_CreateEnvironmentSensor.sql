CREATE TABLE IF NOT EXISTS environmentsensor
(
    environmentSensorId INT NOT NULL AUTO_INCREMENT,

    sensorName VARCHAR(100) NOT NULL,
    locationName VARCHAR(100) NULL,

    effectiveFromDate DATE NOT NULL,
    effectiveToDate DATE NULL,

    isActive TINYINT(1) NOT NULL DEFAULT 1,

    createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedDateTime DATETIME NULL,

    PRIMARY KEY (environmentSensorId),

    CONSTRAINT chkEnvironmentSensorEffectiveDateRange
        CHECK (
            effectiveToDate IS NULL
            OR effectiveToDate > effectiveFromDate
        )
);

CREATE UNIQUE INDEX uxEnvironmentSensorNameFromDate
ON environmentsensor
(
    sensorName,
    effectiveFromDate
);

CREATE INDEX ixEnvironmentSensorLookup
ON environmentsensor
(
    sensorName,
    effectiveFromDate,
    effectiveToDate,
    isActive
);

INSERT INTO environmentsensor
(
    sensorName,
    effectiveFromDate
)
SELECT DISTINCT
    sensorName,
    '2025-05-01'
FROM environmentreading;