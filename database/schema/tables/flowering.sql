DROP TABLE IF EXISTS `flowering`;

CREATE TABLE `flowering` (
  `floweringId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for flowering record',
  `plantId` int NOT NULL COMMENT 'Plant that flowered',
  `startDate` date NOT NULL COMMENT 'Date flowering started',
  `endDate` date DEFAULT NULL COMMENT 'Date flowering ended (NULL = currently flowering)',
  `spikeCount` int DEFAULT NULL COMMENT 'Number of flower spikes',
  `flowerCount` int DEFAULT NULL COMMENT 'Approximate number of flowers',
  `floweringNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Grower notes about flowering quality',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`floweringId`),
  KEY `ixFloweringPlantStartDate` (`plantId`,`startDate`),
  CONSTRAINT `chkFloweringIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';

