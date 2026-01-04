DROP TABLE IF EXISTS `plantevent`;

CREATE TABLE `plantevent` (
  `plantEventId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant event',
  `plantId` int NOT NULL COMMENT 'Plant the event relates to',
  `eventCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured event type (Watering, Feeding, Pest, etc)',
  `eventDateTime` datetime NOT NULL COMMENT 'Date and time of event (local time)',
  `eventDetails` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text description of event',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`plantEventId`),
  KEY `ixPlantEventPlantDateTime` (`plantId`,`eventDateTime`),
  KEY `ixPlantEventEventCode` (`eventCode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='General-purpose event log for plant care and observations.';

