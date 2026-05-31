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

