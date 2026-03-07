CREATE TABLE IF NOT EXISTS `growthmedium` (
  `growthMediumId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for growing medium',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Name of the growing medium, e.g. "Orchid Focus", "Sphagnum Moss", "Bark Chips"',
  `description` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional description or notes about the growing medium',
  `isActive` bit(1) NOT NULL DEFAULT b'1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `createdAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`growthMediumId`),
  UNIQUE KEY `uqname` (`name`),
  CONSTRAINT `chkGrowthMediumIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Lookup table for types of growing media used for plants.';

