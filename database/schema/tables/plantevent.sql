DROP TABLE IF EXISTS `plantevent`;

CREATE TABLE `plantevent` (
  `plantEventId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant event',
  `plantId` int NOT NULL COMMENT 'Plant the event relates to',
  `eventCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured event type (Watering, Feeding, Pest, etc)',
  `eventDateTime` datetime NOT NULL COMMENT 'Date and time of event (local time)',
  `eventDetails` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text description of event',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`plantEventId`),
  KEY `ixPlantEventPlantDateTime` (`plantId`,`eventDateTime`),
  KEY `ixPlantEventEventCode` (`eventCode`),
  CONSTRAINT `chkPlantEventIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='General-purpose event log for plant care and observations.';

