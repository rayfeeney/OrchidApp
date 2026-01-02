DROP TABLE IF EXISTS `location`;

CREATE TABLE `location` (
  `locationId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for a physical location',
  `locationName` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Human-readable location name',
  `locationTypeCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Type of location (Greenhouse, House, Garden, etc)',
  `locationNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text notes about this location',
  `climateCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'General climate classification',
  `climateNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text climate description',
  `locationGeneralNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Other notes about the location',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = active location, 0 = retired',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`locationId`),
  KEY `ixLocationName` (`locationName`),
  KEY `ixLocationTypeCode` (`locationTypeCode`),
  KEY `ixLocationIsActive` (`isActive`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Locations where plants may be kept over time.';

