CREATE TABLE IF NOT EXISTS `plantlocationhistory` (
  `plantLocationHistoryId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  `plantId` int NOT NULL COMMENT 'Plant being moved',
  `locationId` int NOT NULL COMMENT 'Location plant is moved to',
  `startDateTime` datetime NOT NULL COMMENT 'Date and time plant entered this location',
  `endDateTime` datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  `moveReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for movement',
  `moveReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for movement',
  `plantLocationNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about this placement',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`plantLocationHistoryId`),
  KEY `ixPlantLocationHistoryPlantTime` (`plantId`,`startDateTime`,`endDateTime`),
  KEY `ixPlantLocationHistoryLocationTime` (`locationId`,`startDateTime`,`endDateTime`),
  CONSTRAINT `chkPlantLocationHistoryIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';

DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `trg_plh_single_open_before_insert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM orchids.plantlocationhistory
            WHERE plantId = NEW.plantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';
        END IF;
    END IF;
END */;;
DELIMITER ;

DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `trg_plh_single_open_before_update` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN
    -- Only care if the updated row would be an active open row
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM orchids.plantlocationhistory
            WHERE plantId = NEW.plantId
              AND isActive = 1
              AND endDateTime IS NULL
              AND plantLocationHistoryId <> OLD.plantLocationHistoryId
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';
        END IF;
    END IF;
END */;;
DELIMITER ;

