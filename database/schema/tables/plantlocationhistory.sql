DROP TABLE IF EXISTS `plantlocationhistory`;

CREATE TABLE `plantlocationhistory` (
  `plantLocationHistoryId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  `plantId` int NOT NULL COMMENT 'Plant being moved',
  `locationId` int NOT NULL COMMENT 'Location plant is moved to',
  `startDateTime` datetime NOT NULL COMMENT 'Date and time plant entered this location',
  `endDateTime` datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  `moveReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for movement',
  `moveReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for movement',
  `plantLocationNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about this placement',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`plantLocationHistoryId`),
  KEY `ixPlantLocationHistoryPlantTime` (`plantId`,`startDateTime`,`endDateTime`),
  KEY `ixPlantLocationHistoryLocationTime` (`locationId`,`startDateTime`,`endDateTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';

