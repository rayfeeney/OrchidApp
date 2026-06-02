CREATE TABLE IF NOT EXISTS environmentperiodrule
(
    environmentPeriodRuleId INT NOT NULL AUTO_INCREMENT,
    periodCode VARCHAR(20) NOT NULL,
    periodName VARCHAR(50) NOT NULL,
    startTime TIME NOT NULL,
    endTime TIME NOT NULL,
    effectiveFromDate DATE NOT NULL,
    effectiveToDate DATE NULL,
    isActive TINYINT(1) NOT NULL DEFAULT 1,
    createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedDateTime DATETIME NULL,
    PRIMARY KEY (environmentPeriodRuleId),
    CONSTRAINT chkEnvironmentPeriodRulePeriodCode
        CHECK (periodCode IN ('DAY', 'NIGHT')),
    CONSTRAINT chkEnvironmentPeriodRuleEffectiveDateRange
        CHECK (
            effectiveToDate IS NULL
            OR effectiveToDate > effectiveFromDate
        )
);

CREATE UNIQUE INDEX uxEnvironmentPeriodRulePeriodFromDate
ON environmentperiodrule
(
    periodCode,
    effectiveFromDate
);

CREATE INDEX ixEnvironmentPeriodRulePeriodDateRange
ON environmentperiodrule
(
    periodCode,
    effectiveFromDate,
    effectiveToDate,
    isActive
);

INSERT INTO environmentperiodrule
(
    periodCode,
    periodName,
    startTime,
    endTime,
    effectiveFromDate,
    effectiveToDate
)
SELECT
    'DAY',
    'Day',
    '10:00:00',
    '16:00:00',
    '2025-05-01',
    NULL
WHERE NOT EXISTS
(
    SELECT 1
    FROM environmentperiodrule
    WHERE periodCode = 'DAY'
      AND effectiveFromDate = '2025-05-01'
);

INSERT INTO environmentperiodrule
(
    periodCode,
    periodName,
    startTime,
    endTime,
    effectiveFromDate,
    effectiveToDate
)
SELECT
    'NIGHT',
    'Night',
    '22:00:00',
    '04:00:00',
    '2025-05-01',
    NULL
WHERE NOT EXISTS
(
    SELECT 1
    FROM environmentperiodrule
    WHERE periodCode = 'NIGHT'
      AND effectiveFromDate = '2025-05-01'
);


CREATE TABLE IF NOT EXISTS environmenttargetrule
(
    environmentTargetRuleId INT NOT NULL AUTO_INCREMENT,

    locationName VARCHAR(100) NOT NULL,

    monthNumber TINYINT NOT NULL,

    expectedDayTemperatureCelsius DECIMAL(4,1) NOT NULL,
    expectedNightTemperatureCelsius DECIMAL(4,1) NOT NULL,
    expectedRelativeHumidity DECIMAL(4,1) NOT NULL,

    effectiveFromDate DATE NOT NULL,
    effectiveToDate DATE NULL,

    notes VARCHAR(500) NULL,

    isActive TINYINT(1) NOT NULL DEFAULT 1,

    createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedDateTime DATETIME NULL,

    PRIMARY KEY (environmentTargetRuleId),

    CONSTRAINT chkEnvironmentTargetRuleMonthNumber
        CHECK (monthNumber BETWEEN 1 AND 12),

    CONSTRAINT chkEnvironmentTargetRuleHumidity
        CHECK (
            expectedRelativeHumidity >= 0.0
            AND expectedRelativeHumidity <= 100.0
        ),

    CONSTRAINT chkEnvironmentTargetRuleEffectiveDateRange
        CHECK (
            effectiveToDate IS NULL
            OR effectiveToDate > effectiveFromDate
        )
);

CREATE UNIQUE INDEX uxEnvironmentTargetRuleLocationMonthFromDate
ON environmenttargetrule
(
    locationName,
    monthNumber,
    effectiveFromDate
);

CREATE INDEX ixEnvironmentTargetRuleLookup
ON environmenttargetrule
(
    locationName,
    monthNumber,
    effectiveFromDate,
    effectiveToDate,
    isActive
);