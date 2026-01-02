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
  PRIMARY KEY (`floweringId`),
  KEY `ixFloweringPlantStartDate` (`plantId`,`startDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';

