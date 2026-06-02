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

