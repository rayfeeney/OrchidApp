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

