CREATE TABLE IF NOT EXISTS `repotting` (
  `repottingId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for repotting event',
  `plantId` int(11) NOT NULL COMMENT 'Plant that was repotted',
  `repotDate` datetime NOT NULL,
  `oldMediumNotes` text DEFAULT NULL COMMENT 'Notes on previous medium condition',
  `newMediumNotes` text DEFAULT NULL COMMENT 'Notes on new medium',
  `potSize` varchar(50) DEFAULT NULL COMMENT 'Pot size used',
  `repotReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for repotting',
  `repotReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation for repotting',
  `repottingNotes` text DEFAULT NULL COMMENT 'Additional repotting notes',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `oldGrowthMediumId` int(11) DEFAULT NULL COMMENT 'Foreign key to growthmedium.growthMediumId representing the old growth medium used before repotting',
  `newGrowthMediumId` int(11) NOT NULL,
  PRIMARY KEY (`repottingId`),
  KEY `ixRepottingPlantRepotDate` (`plantId`,`repotDate`),
  KEY `ixRepotStatusLookup` (`plantId`,`isActive`,`repotDate` DESC,`newGrowthMediumId`),
  CONSTRAINT `fkRepottingPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `fk_repotting_new_growthmedium` FOREIGN KEY (`newGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `fk_repotting_old_growthmedium` FOREIGN KEY (`oldGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `chkRepottingIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB    COMMENT='Repotting history per plant.';

