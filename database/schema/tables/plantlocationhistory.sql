CREATE TABLE IF NOT EXISTS `plantlocationhistory` (
  `plantLocationHistoryId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  `plantId` int(11) NOT NULL COMMENT 'Plant being moved',
  `locationId` int(11) NOT NULL COMMENT 'Location plant is moved to',
  `startDateTime` datetime NOT NULL COMMENT 'Date and time plant entered this location',
  `endDateTime` datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  `moveReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for movement',
  `moveReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation for movement',
  `plantLocationNotes` text DEFAULT NULL COMMENT 'Additional notes about this placement',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`plantLocationHistoryId`),
  KEY `ixPlantLocationHistoryPlantTime` (`plantId`,`startDateTime`,`endDateTime`),
  KEY `ixPlantLocationHistoryLocationTime` (`locationId`,`startDateTime`,`endDateTime`),
  KEY `ixPlhStatusLookup` (`plantId`,`isActive`,`startDateTime` DESC,`locationId`),
  CONSTRAINT `chkPlantLocationHistoryDateOrder` CHECK (`endDateTime` is null or `endDateTime` > `startDateTime`),
  CONSTRAINT `chkPlantLocationHistoryIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB    COMMENT='Time-based history of where plants have been located.';

DELIMITER ;;

DELIMITER ;

ALTER DATABASE `orchids` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci ;

DELIMITER ;;

DELIMITER ;

ALTER DATABASE `orchids` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ;

