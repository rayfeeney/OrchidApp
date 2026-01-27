DROP TABLE IF EXISTS `plant`;

CREATE TABLE `plant` (
  `plantId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for individual plant',
  `taxonId` int NOT NULL COMMENT 'Linked taxonomic identification (taxon); always populated (if unidentified at taxon, the taxon all null record is linked)',
  `plantTag` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Physical label on the pot',
  `plantName` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional informal name',
  `acquisitionDate` date DEFAULT NULL COMMENT 'Date plant was acquired',
  `acquisitionSource` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Where the plant was obtained from',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = currently in collection, 0 = no longer present',
  `endReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason plant left collection (Died, GivenAway, Split, etc)',
  `endDate` date DEFAULT NULL COMMENT 'Date plant left collection',
  `endNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of plant end-of-life',
  `plantNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'General grower notes for this plant',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`plantId`),
  UNIQUE KEY `uqPlantPlantTag` (`plantTag`),
  KEY `ixPlantIsActive` (`isActive`),
  KEY `ixPlantEndReasonCode` (`endReasonCode`),
  KEY `ixPlantTaxonId` (`taxonId`),
  CONSTRAINT `chkPlantIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orchid plants tracked in the collection.';

