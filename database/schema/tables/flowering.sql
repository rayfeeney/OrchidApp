CREATE TABLE IF NOT EXISTS `flowering` (
  `floweringId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for flowering record',
  `plantId` int(11) NOT NULL COMMENT 'Plant that flowered',
  `startDate` datetime NOT NULL,
  `endDate` datetime DEFAULT NULL,
  `spikeCount` int(11) DEFAULT NULL COMMENT 'Number of flower spikes',
  `flowerCount` int(11) DEFAULT NULL COMMENT 'Approximate number of flowers',
  `floweringNotes` text DEFAULT NULL COMMENT 'Grower notes about flowering quality',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`floweringId`),
  KEY `ixFloweringPlantStartDate` (`plantId`,`startDate`),
  KEY `ixFlowerStatusLookup` (`plantId`,`isActive`,`startDate` DESC),
  CONSTRAINT `fkFloweringPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkFloweringIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB    COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';

