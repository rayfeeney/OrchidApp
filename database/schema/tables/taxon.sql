DROP TABLE IF EXISTS `taxon`;

CREATE TABLE `taxon` (
  `taxonId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for species or hybrid',
  `genusId` int NOT NULL COMMENT 'Foreign key to genus.genusId (taxonomic genus)',
  `speciesName` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Species epithet (NULL for hybrids)',
  `hybridName` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Registered hybrid name (NULL if unnamed or species)',
  `growthCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured growth habit code',
  `growthNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text notes about growth characteristics',
  `taxonNotes` text COLLATE utf8mb4_unicode_ci,
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 Indicates this taxon represents the current accepted classification for assignments; 0 Indicates inactive taxa remaining historically valid and must not be deleted',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  `genusOnlyKey` int GENERATED ALWAYS AS ((case when ((`speciesName` is null) and (`hybridName` is null)) then `genusId` else NULL end)) STORED,
  `genusSpeciesKey` varchar(255) COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS ((case when (`speciesName` is not null) then concat(`genusId`,_utf8mb4':',`speciesName`) else NULL end)) STORED,
  `genusHybridKey` varchar(255) COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS ((case when (`hybridName` is not null) then concat(`genusId`,_utf8mb4':',`hybridName`) else NULL end)) STORED,
  `isSystemManaged` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 Indicates this taxon row is created and managed by the system and must not be edited by end users; 0 Indicates user-managed taxon records',
  PRIMARY KEY (`taxonId`),
  UNIQUE KEY `uxTaxon_GenusOnly` (`genusOnlyKey`),
  UNIQUE KEY `uxTaxon_GenusSpecies` (`genusSpeciesKey`),
  UNIQUE KEY `uxTaxon_GenusHybrid` (`genusHybridKey`),
  KEY `ixTaxonGenusId` (`genusId`),
  KEY `ixTaxonIsActive` (`isActive`),
  CONSTRAINT `chkTaxon_Shape` CHECK ((((`speciesName` is null) and (`hybridName` is null)) or ((`speciesName` is not null) and (`hybridName` is null)) or ((`speciesName` is null) and (`hybridName` is not null)))),
  CONSTRAINT `chkTaxonIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Taxonomic information for orchid species and hybrids.';

