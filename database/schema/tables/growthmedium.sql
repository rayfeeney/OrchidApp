CREATE TABLE IF NOT EXISTS `growthmedium` (
  `growthMediumId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for growing medium',
  `name` varchar(100) NOT NULL COMMENT 'Name of the growing medium, e.g. "Orchid Focus", "Sphagnum Moss", "Bark Chips"',
  `description` varchar(500) DEFAULT NULL COMMENT 'Optional description or notes about the growing medium',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`growthMediumId`),
  UNIQUE KEY `uqname` (`name`),
  CONSTRAINT `chkGrowthMediumIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB    COMMENT='Lookup table for types of growing media used for plants.';

