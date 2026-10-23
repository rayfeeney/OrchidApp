CREATE DATABASE IF NOT EXISTS orchids; CREATE DATABASE IF NOT EXISTS EnergyMonitoring; USE orchids; CREATE TABLE IF NOT EXISTS location (locationId INT NOT NULL PRIMARY KEY, locationName VARCHAR(100), isActive TINYINT DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS `environmentreading` (
  `environmentReadingId` bigint(20) NOT NULL AUTO_INCREMENT,
  `sensorName` varchar(255) NOT NULL,
  `readingDateTime` datetime NOT NULL,
  `temperatureCelsius` decimal(6,2) NOT NULL,
  `relativeHumidity` decimal(6,2) NOT NULL,
  `createdAt` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`environmentReadingId`),
  UNIQUE KEY `uqEnvironmentReading_SensorName_ReadingDateTime` (`sensorName`,`readingDateTime`),
  KEY `ixEnvironmentReading_SensorName` (`sensorName`),
  KEY `ixEnvironmentReading_ReadingDateTime` (`readingDateTime`)
) ENGINE=InnoDB  ;


CREATE TABLE IF NOT EXISTS `environmentsensor` (
  `environmentSensorId` int(11) NOT NULL AUTO_INCREMENT,
  `sensorName` varchar(100) NOT NULL,
  `locationName` varchar(100) DEFAULT NULL,
  `effectiveFromDate` date NOT NULL,
  `effectiveToDate` date DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`environmentSensorId`),
  UNIQUE KEY `uxEnvironmentSensorNameFromDate` (`sensorName`,`effectiveFromDate`),
  KEY `ixEnvironmentSensorLookup` (`sensorName`,`effectiveFromDate`,`effectiveToDate`,`isActive`),
  CONSTRAINT `chkEnvironmentSensorEffectiveDateRange` CHECK (`effectiveToDate` is null or `effectiveToDate` > `effectiveFromDate`)
) ENGINE=InnoDB  ;


CREATE TABLE IF NOT EXISTS `environmentperiodrule` (
  `environmentPeriodRuleId` int(11) NOT NULL AUTO_INCREMENT,
  `periodCode` varchar(20) NOT NULL,
  `periodName` varchar(50) NOT NULL,
  `startTime` time NOT NULL,
  `endTime` time NOT NULL,
  `effectiveFromDate` date NOT NULL,
  `effectiveToDate` date DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`environmentPeriodRuleId`),
  UNIQUE KEY `uxEnvironmentPeriodRulePeriodFromDate` (`periodCode`,`effectiveFromDate`),
  KEY `ixEnvironmentPeriodRulePeriodDateRange` (`periodCode`,`effectiveFromDate`,`effectiveToDate`,`isActive`),
  CONSTRAINT `chkEnvironmentPeriodRulePeriodCode` CHECK (`periodCode` in ('DAY','NIGHT')),
  CONSTRAINT `chkEnvironmentPeriodRuleEffectiveDateRange` CHECK (`effectiveToDate` is null or `effectiveToDate` > `effectiveFromDate`)
) ENGINE=InnoDB   ;


CREATE TABLE IF NOT EXISTS `environmenttargetrule` (
  `environmentTargetRuleId` int(11) NOT NULL AUTO_INCREMENT,
  `locationName` varchar(100) NOT NULL,
  `monthNumber` tinyint(4) NOT NULL,
  `expectedDayTemperatureCelsius` decimal(4,1) NOT NULL,
  `expectedNightTemperatureCelsius` decimal(4,1) NOT NULL,
  `expectedRelativeHumidity` decimal(4,1) NOT NULL,
  `effectiveFromDate` date NOT NULL,
  `effectiveToDate` date DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`environmentTargetRuleId`),
  UNIQUE KEY `uxEnvironmentTargetRuleLocationMonthFromDate` (`locationName`,`monthNumber`,`effectiveFromDate`),
  KEY `ixEnvironmentTargetRuleLookup` (`locationName`,`monthNumber`,`effectiveFromDate`,`effectiveToDate`,`isActive`),
  CONSTRAINT `chkEnvironmentTargetRuleMonthNumber` CHECK (`monthNumber` between 1 and 12),
  CONSTRAINT `chkEnvironmentTargetRuleHumidity` CHECK (`expectedRelativeHumidity` >= 0.0 and `expectedRelativeHumidity` <= 100.0),
  CONSTRAINT `chkEnvironmentTargetRuleEffectiveDateRange` CHECK (`effectiveToDate` is null or `effectiveToDate` > `effectiveFromDate`)
) ENGINE=InnoDB  ;


CREATE OR REPLACE VIEW `venvironmentreadingperiod`
AS SELECT `er`.`environmentReadingId`
AS `environmentReadingId`,`er`.`sensorName`
AS `sensorName`,`es`.`locationName`
AS `locationName`,`er`.`readingDateTime`
AS `readingDateTime`,`epr`.`periodCode`
AS `periodCode`,`epr`.`periodName`
AS `periodName`,case when `epr`.`endTime` > `epr`.`startTime` then cast(`er`.`readingDateTime`
AS date) when cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` then cast(`er`.`readingDateTime`
AS date) else cast(`er`.`readingDateTime`
AS date) - interval 1 day end
AS `periodDate`,`er`.`temperatureCelsius`
AS `temperatureCelsius`,`er`.`relativeHumidity`
AS `relativeHumidity` FROM ((`environmentreading` `er` join `environmentsensor` `es` on(`es`.`sensorName` = `er`.`sensorName` and `es`.`isActive` = 1 and cast(`er`.`readingDateTime`
AS date) >= `es`.`effectiveFromDate` and (`es`.`effectiveToDate` is null or cast(`er`.`readingDateTime`
AS date) < `es`.`effectiveToDate`))) join `environmentperiodrule` `epr` on(`epr`.`isActive` = 1 and cast(`er`.`readingDateTime`
AS date) >= `epr`.`effectiveFromDate` and (`epr`.`effectiveToDate` is null or cast(`er`.`readingDateTime`
AS date) < `epr`.`effectiveToDate`) and (`epr`.`endTime` > `epr`.`startTime` and cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` and cast(`er`.`readingDateTime`
AS time) < `epr`.`endTime` or `epr`.`endTime` < `epr`.`startTime` and (cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` or cast(`er`.`readingDateTime`
AS time) < `epr`.`endTime`)))) WHERE `es`.`locationName` is not null;
CREATE OR REPLACE VIEW `venvironmentdailyperiodsummary`
AS SELECT `venvironmentreadingperiod`.`locationName`
AS `locationName`,`venvironmentreadingperiod`.`periodCode`
AS `periodCode`,`venvironmentreadingperiod`.`periodName`
AS `periodName`,`venvironmentreadingperiod`.`periodDate`
AS `periodDate`,count(0)
AS `readingCount`,round(avg(`venvironmentreadingperiod`.`temperatureCelsius`),1)
AS `averageTemperatureCelsius`,round(avg(`venvironmentreadingperiod`.`relativeHumidity`),1)
AS `averageRelativeHumidity`,min(`venvironmentreadingperiod`.`readingDateTime`)
AS `firstReadingDateTime`,max(`venvironmentreadingperiod`.`readingDateTime`)
AS `lastReadingDateTime` FROM `venvironmentreadingperiod` group by `venvironmentreadingperiod`.`locationName`,`venvironmentreadingperiod`.`periodCode`,`venvironmentreadingperiod`.`periodName`,`venvironmentreadingperiod`.`periodDate`;
CREATE OR REPLACE VIEW `venvironmentlastsevendayssummary`
AS SELECT `actual`.`locationName`
AS `locationName`,`actual`.`averageDayTemperatureCelsius`
AS `averageDayTemperatureCelsius`,`target`.`expectedDayTemperatureCelsius`
AS `expectedDayTemperatureCelsius`,`actual`.`averageNightTemperatureCelsius`
AS `averageNightTemperatureCelsius`,`target`.`expectedNightTemperatureCelsius`
AS `expectedNightTemperatureCelsius`,`actual`.`averageRelativeHumidity`
AS `averageRelativeHumidity`,`target`.`expectedRelativeHumidity`
AS `expectedRelativeHumidity`,`actual`.`readingCount`
AS `readingCount`,`actual`.`firstReadingDateTime`
AS `firstReadingDateTime`,`actual`.`lastReadingDateTime`
AS `lastReadingDateTime` FROM ((SELECT `venvironmentreadingperiod`.`locationName`
AS `locationName`,round(avg(case when `venvironmentreadingperiod`.`periodCode` = 'DAY' then `venvironmentreadingperiod`.`temperatureCelsius` else NULL end),1)
AS `averageDayTemperatureCelsius`,round(avg(case when `venvironmentreadingperiod`.`periodCode` = 'NIGHT' then `venvironmentreadingperiod`.`temperatureCelsius` else NULL end),1)
AS `averageNightTemperatureCelsius`,round(avg(`venvironmentreadingperiod`.`relativeHumidity`),1)
AS `averageRelativeHumidity`,count(0)
AS `readingCount`,min(`venvironmentreadingperiod`.`readingDateTime`)
AS `firstReadingDateTime`,max(`venvironmentreadingperiod`.`readingDateTime`)
AS `lastReadingDateTime` FROM `venvironmentreadingperiod` WHERE `venvironmentreadingperiod`.`readingDateTime` >= curdate() - interval 7 day and `venvironmentreadingperiod`.`readingDateTime` < curdate() + interval 1 day group by `venvironmentreadingperiod`.`locationName`) `actual` join `environmenttargetrule` `target` on(`target`.`locationName` = `actual`.`locationName` and `target`.`monthNumber` = month(curdate()) and `target`.`isActive` = 1 and curdate() >= `target`.`effectiveFromDate` and (`target`.`effectiveToDate` is null or curdate() < `target`.`effectiveToDate`)));
USE EnergyMonitoring;


CREATE TABLE IF NOT EXISTS TapoDevice
(
    TapoDeviceKey INT NOT NULL AUTO_INCREMENT,
    DeviceName VARCHAR(100) NOT NULL,
    Model VARCHAR(20) NOT NULL,
    IpAddress VARCHAR(45) NULL,
    IsActive TINYINT(1) NOT NULL DEFAULT 1,
    CreatedUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (TapoDeviceKey)
);


CREATE TABLE IF NOT EXISTS TapoEnergyHourly
(
    TapoDeviceKey INT NOT NULL,
    HourStartUtc DATETIME NOT NULL,
    EnergyWh INT NOT NULL,
    LoadedUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY
    (
        TapoDeviceKey,
        HourStartUtc
    ),

    FOREIGN KEY (TapoDeviceKey)
        REFERENCES TapoDevice (TapoDeviceKey)
);


CREATE TABLE IF NOT EXISTS TapoPowerReading
(
    TapoDeviceKey INT NOT NULL,
    ReadingUtc DATETIME NOT NULL,
    PowerWatts INT NOT NULL,
    LoadedUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY
    (
        TapoDeviceKey,
        ReadingUtc
    ),

    FOREIGN KEY (TapoDeviceKey)
        REFERENCES TapoDevice (TapoDeviceKey)
);


CREATE TABLE IF NOT EXISTS EnphaseInterval
(
    IntervalEndUtc DATETIME NOT NULL,
    ProducedWh INT NULL,
    ConsumedWh INT NULL,
    ImportedWh INT NULL,
    ExportedWh INT NULL,
    LoadedUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (IntervalEndUtc)
);


CREATE TABLE IF NOT EXISTS LoadRun
(
    LoadRunKey BIGINT NOT NULL AUTO_INCREMENT,
    SourceName VARCHAR(50) NOT NULL,
    StartedUtc DATETIME NOT NULL,
    CompletedUtc DATETIME NULL,
    RowsReceived INT NULL,
    RowsInserted INT NULL,
    RowsUpdated INT NULL,
    Status VARCHAR(20) NOT NULL,
    ErrorMessage TEXT NULL,

    PRIMARY KEY (LoadRunKey)
);
CREATE TABLE IF NOT EXISTS EnergyMonitoring.MonitoringDevice
(
    MonitoringDeviceId INT NOT NULL AUTO_INCREMENT
        COMMENT 'Internal identifier for a monitoring device',

    SourceSystemCode VARCHAR(30) NOT NULL
        COMMENT 'Source system providing the device or sensor, e.g. Govee or Tapo',

    SourceDeviceId INT NOT NULL
        COMMENT 'Device identifier within the source system',

    DeviceName VARCHAR(100) NOT NULL
        COMMENT 'Human-readable device or sensor name',

    IsActive TINYINT(1) NOT NULL DEFAULT 1
        COMMENT '1 = active device, 0 = retired',

    CreatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'Record creation timestamp',

    UpdatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
        COMMENT 'Last update timestamp',

    PRIMARY KEY (MonitoringDeviceId),

    UNIQUE KEY uxMonitoringDeviceSource
        (SourceSystemCode, SourceDeviceId),

    KEY ixMonitoringDeviceName
        (DeviceName),

    KEY ixMonitoringDeviceActive
        (IsActive),

    CONSTRAINT chkMonitoringDeviceIsActive
        CHECK (IsActive IN (0,1))
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci
COMMENT='Master list of monitoring devices and sensors from different source systems.';
CREATE TABLE IF NOT EXISTS EnergyMonitoring.MonitoringDeviceLocationHistory
(
    MonitoringDeviceLocationHistoryId INT NOT NULL AUTO_INCREMENT
        COMMENT 'Internal identifier for monitoring device location history row',

    MonitoringDeviceId INT NOT NULL
        COMMENT 'Monitoring device being located',

    LocationId INT NOT NULL
        COMMENT 'Physical location of the monitoring device',

    StartDateTime DATETIME NOT NULL
        COMMENT 'Date and time device entered this location',

    EndDateTime DATETIME DEFAULT NULL
        COMMENT 'Date and time device left this location (NULL = current)',

    IsActive TINYINT(1) NOT NULL DEFAULT 1
        COMMENT '1 = valid location assignment, 0 = superseded or erroneous',

    CreatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'Record creation timestamp',

    UpdatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
        COMMENT 'Last update timestamp',

    PRIMARY KEY (MonitoringDeviceLocationHistoryId),

    KEY ixMonitoringDeviceLocationHistoryDeviceTime
        (MonitoringDeviceId, StartDateTime, EndDateTime),

    KEY ixMonitoringDeviceLocationHistoryLocationTime
        (LocationId, StartDateTime, EndDateTime),

    CONSTRAINT fkMonitoringDeviceLocationHistoryDevice
        FOREIGN KEY (MonitoringDeviceId)
        REFERENCES EnergyMonitoring.MonitoringDevice (MonitoringDeviceId),

    CONSTRAINT fkMonitoringDeviceLocationHistoryLocation
        FOREIGN KEY (LocationId)
        REFERENCES orchids.location (locationId),

    CONSTRAINT chkMonitoringDeviceLocationHistoryIsActive
        CHECK (IsActive IN (0,1)),

    CONSTRAINT chkMonitoringDeviceLocationHistoryDateOrder
        CHECK (EndDateTime IS NULL OR EndDateTime > StartDateTime)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci
COMMENT='Time-based history of where monitoring devices and sensors have been located.';
CREATE TABLE IF NOT EXISTS EnergyMonitoring.Tariff
(
    TariffId                    INT NOT NULL AUTO_INCREMENT,
    SupplierName                VARCHAR(100) NOT NULL,
    TariffName                  VARCHAR(200) NOT NULL,
    EffectiveFromDate           DATE NOT NULL,
    EffectiveToDate             DATE NULL,
    ImportRatePencePerKWh       DECIMAL(10,4) NOT NULL,
    StandingChargePencePerDay   DECIMAL(10,4) NOT NULL,
    ExportRatePencePerKWh       DECIMAL(10,4) NULL,
    ExitFeeGBP                  DECIMAL(10,2) NULL,
    ExitFeeAppliesUntilDate     DATE NULL,

    PRIMARY KEY (TariffId)
);
CREATE TABLE IF NOT EXISTS EnergyMonitoring.GreenhouseTargetLocationMap
(
    LocationId              INT NOT NULL,
    TargetRuleLocationName  VARCHAR(100) NOT NULL,

    PRIMARY KEY (LocationId)
);
USE orchids;
INSERT IGNORE INTO location VALUES (1,'Cool side',1),(2,'Hot side',1);
INSERT IGNORE INTO environmentsensor (environmentSensorId,sensorName,locationName,effectiveFromDate) VALUES (1,'cool','Cool side','2025-01-01'),(2,'hot','Hot side','2025-01-01');
INSERT IGNORE INTO environmentperiodrule (environmentPeriodRuleId,periodCode,periodName,startTime,endTime,effectiveFromDate) VALUES (1,'DAY','Day','10:00','16:00','2025-01-01'),(2,'NIGHT','Night','22:00','04:00','2025-01-01');
INSERT IGNORE INTO environmenttargetrule (environmentTargetRuleId,locationName,monthNumber,expectedDayTemperatureCelsius,expectedNightTemperatureCelsius,expectedRelativeHumidity,effectiveFromDate) VALUES (1,'Cool side',10,20,12,70,'2025-01-01'),(2,'Hot side',10,25,15,70,'2025-01-01');
INSERT IGNORE INTO environmentreading (environmentReadingId,sensorName,readingDateTime,temperatureCelsius,relativeHumidity) VALUES
(1,'cool','2026-10-16 10:00:00',10,70),(2,'cool','2026-10-16 10:30:00',10,70),(3,'cool','2026-10-16 11:00:00',40,70),
(4,'cool','2026-10-16 16:00:00',50,70),(5,'cool','2026-10-15 23:00:00',10,70),(6,'cool','2026-10-16 02:00:00',20,70),
(7,'hot','2026-10-16 10:00:00',25,70),(8,'cool','2026-10-16 04:00:00',50,70),
(9,'cool','2026-10-15 12:00:00',90,70),(10,'cool','2026-10-24 00:00:00',90,70),
(11,'cool','2026-10-23 12:00:00',20,70);
USE EnergyMonitoring;
INSERT IGNORE INTO TapoDevice (TapoDeviceKey,DeviceName,Model) VALUES (1,'Cool heater','P110'),(2,'Hot heater','P110');
INSERT IGNORE INTO MonitoringDevice (MonitoringDeviceId,SourceSystemCode,SourceDeviceId,DeviceName) VALUES (1,'Tapo',1,'Cool heater'),(2,'Tapo',2,'Hot heater');
INSERT IGNORE INTO MonitoringDeviceLocationHistory (MonitoringDeviceLocationHistoryId,MonitoringDeviceId,LocationId,StartDateTime) VALUES (1,1,1,'2025-01-01'),(2,2,2,'2025-01-01');
INSERT IGNORE INTO GreenhouseTargetLocationMap VALUES (1,'Cool side'),(2,'Hot side');
INSERT IGNORE INTO Tariff (TariffId,SupplierName,TariffName,EffectiveFromDate,EffectiveToDate,ImportRatePencePerKWh,StandingChargePencePerDay) VALUES (1,'Test','Old','2026-01-01','2026-10-16',25,0),(2,'Test','New','2026-10-17',NULL,30,0);
INSERT IGNORE INTO TapoEnergyHourly (TapoDeviceKey,HourStartUtc,EnergyWh) VALUES (1,'2026-10-16 09:00:00',1000),(2,'2026-10-16 09:00:00',2000);
