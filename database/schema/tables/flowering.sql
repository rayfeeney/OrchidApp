CREATE TABLE IF NOT EXISTS `flowering` (
  `floweringId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for flowering record',
  `plantId` int NOT NULL COMMENT 'Plant that flowered',
  `startDate` datetime NOT NULL,
  `endDate` datetime DEFAULT NULL,
  `spikeCount` int DEFAULT NULL COMMENT 'Number of flower spikes',
  `flowerCount` int DEFAULT NULL COMMENT 'Approximate number of flowers',
  `floweringNotes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Grower notes about flowering quality',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`floweringId`),
  KEY `ixFloweringPlantStartDate` (`plantId`,`startDate`),
  KEY `ixFlowerStatusLookup` (`plantId`,`isActive`,`startDate` DESC),
  CONSTRAINT `chkFloweringIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';

