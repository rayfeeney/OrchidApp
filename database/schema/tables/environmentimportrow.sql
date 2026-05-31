CREATE TABLE IF NOT EXISTS `environmentimportrow` (
  `environmentImportFileId` bigint(20) NOT NULL,
  `sourceRowNumber` int(11) NOT NULL,
  `rawTimestampText` varchar(100) NOT NULL,
  `rawTemperatureText` varchar(100) DEFAULT NULL,
  `rawHumidityText` varchar(100) DEFAULT NULL,
  `readingDateTime` datetime NOT NULL,
  `temperatureCelsius` decimal(6,2) NOT NULL,
  `relativeHumidity` decimal(6,2) NOT NULL,
  PRIMARY KEY (`environmentImportFileId`,`sourceRowNumber`),
  KEY `ixEnvironmentImportRow_ReadingDateTime` (`readingDateTime`)
) ENGINE=InnoDB  ;

