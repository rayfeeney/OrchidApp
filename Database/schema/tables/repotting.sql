DROP TABLE IF EXISTS `repotting`;

CREATE TABLE `repotting` (
  `repottingId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for repotting event',
  `plantId` int NOT NULL COMMENT 'Plant that was repotted',
  `repotDate` date NOT NULL COMMENT 'Date of repotting',
  `oldMediumCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Previous potting medium',
  `oldMediumNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Notes on previous medium condition',
  `newMediumCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'New potting medium',
  `newMediumNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Notes on new medium',
  `potSize` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Pot size used',
  `repotReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for repotting',
  `repotReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for repotting',
  `repottingNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional repotting notes',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`repottingId`),
  KEY `ixRepottingPlantRepotDate` (`plantId`,`repotDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Repotting history per plant.';

