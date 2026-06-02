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

