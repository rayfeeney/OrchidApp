CREATE TABLE IF NOT EXISTS `location` (
  `locationId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for a physical location',
  `locationName` varchar(100) NOT NULL COMMENT 'Human-readable location name',
  `locationTypeCode` varchar(30) DEFAULT NULL COMMENT 'Type of location (Greenhouse, House, Garden, etc)',
  `locationNotes` text DEFAULT NULL COMMENT 'Free-text notes about this location',
  `climateCode` varchar(30) DEFAULT NULL COMMENT 'General climate classification',
  `climateNotes` text DEFAULT NULL COMMENT 'Free-text climate description',
  `locationGeneralNotes` text DEFAULT NULL COMMENT 'Other notes about the location',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active location, 0 = retired',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`locationId`),
  KEY `ixLocationName` (`locationName`),
  KEY `ixLocationTypeCode` (`locationTypeCode`),
  KEY `ixLocationIsActive` (`isActive`),
  KEY `ixLocationActiveName` (`isActive`,`locationName`),
  CONSTRAINT `chkLocationIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB    COMMENT='Locations where plants may be kept over time.';

