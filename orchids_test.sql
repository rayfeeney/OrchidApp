/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `flowering` (
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
  KEY `plantId` (`plantId`),
  CONSTRAINT `flowering_ibfk_1` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkFloweringIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `genus` (
  `genusId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for genus',
  `genusName` varchar(100) NOT NULL COMMENT 'Canonical genus name (e.g. Phalaenopsis)',
  `genusNotes` text DEFAULT NULL COMMENT 'General notes about this genus',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 Indicates this genus represents the current accepted classification for assignments; 0 Indicates inactive genus remaining historically valid and must not be deleted',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`genusId`),
  UNIQUE KEY `uqGenus_GenusName` (`genusName`),
  CONSTRAINT `chkGenusIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Genus information for orchid species and hybrids.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `growthmedium` (
  `growthMediumId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for growing medium',
  `name` varchar(100) NOT NULL COMMENT 'Name of the growing medium, e.g. "Orchid Focus", "Sphagnum Moss", "Bark Chips"',
  `description` varchar(500) DEFAULT NULL COMMENT 'Optional description or notes about the growing medium',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`growthMediumId`),
  UNIQUE KEY `uqname` (`name`),
  CONSTRAINT `chkGrowthMediumIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Lookup table for types of growing media used for plants.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `location` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Locations where plants may be kept over time.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `observationtype` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `typeCode` varchar(30) NOT NULL,
  `displayName` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `isSystem` tinyint(1) NOT NULL DEFAULT 0,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `ux_observationtype_typeCode` (`typeCode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Defines subtypes of Observation records. System rows may drive application behaviour.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `phoneticprefix` (
  `prefixId` int(11) NOT NULL AUTO_INCREMENT,
  `prefix` char(2) NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`prefixId`),
  UNIQUE KEY `uqPhoneticPrefixPrefix` (`prefix`),
  CONSTRAINT `chkPhoneticPrefixIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plant` (
  `plantId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for individual plant',
  `taxonId` int(11) NOT NULL COMMENT 'Linked taxonomic identification (taxon); always populated (if unidentified at taxon, the taxon all null record is linked)',
  `plantName` varchar(100) DEFAULT NULL COMMENT 'Optional informal name',
  `acquisitionDate` datetime DEFAULT NULL COMMENT 'Start of the plant lifecycle in the system. All events must occur on or after this datetime. Set on creation (including split-created plants).',
  `acquisitionSource` varchar(150) DEFAULT NULL COMMENT 'Where the plant was obtained from',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = currently in collection, 0 = no longer present',
  `endReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason plant left collection (Died, GivenAway, Split, etc)',
  `endDate` datetime DEFAULT NULL COMMENT 'End of the plant lifecycle. No events may occur after this datetime. Set by terminal events (e.g. split, disposal).',
  `endNotes` text DEFAULT NULL COMMENT 'Free-text explanation of plant end-of-life',
  `plantNotes` text DEFAULT NULL COMMENT 'General grower notes for this plant',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `plantTag` char(8) NOT NULL COMMENT 'System-generated permanent accession identity',
  PRIMARY KEY (`plantId`),
  UNIQUE KEY `uqPlantPlantTag` (`plantTag`),
  KEY `ixPlantIsActive` (`isActive`),
  KEY `ixPlantEndReasonCode` (`endReasonCode`),
  KEY `taxonId` (`taxonId`),
  CONSTRAINT `plant_ibfk_1` FOREIGN KEY (`taxonId`) REFERENCES `taxon` (`taxonId`),
  CONSTRAINT `chkPlantIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orchid plants tracked in the collection.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantevent` (
  `plantEventId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant event',
  `plantId` int(11) NOT NULL COMMENT 'Plant the event relates to',
  `eventDateTime` datetime NOT NULL COMMENT 'Date and time of event (local time)',
  `eventDetails` text DEFAULT NULL COMMENT 'Free-text description of event',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `observationTypeId` int(11) NOT NULL,
  PRIMARY KEY (`plantEventId`),
  KEY `observationTypeId` (`observationTypeId`),
  KEY `plantId` (`plantId`),
  CONSTRAINT `plantevent_ibfk_1` FOREIGN KEY (`observationTypeId`) REFERENCES `observationtype` (`Id`),
  CONSTRAINT `plantevent_ibfk_2` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantEventIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='General-purpose event log for plant care and observations.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantlocationhistory` (
  `plantLocationHistoryId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  `plantId` int(11) NOT NULL COMMENT 'Plant being moved',
  `locationId` int(11) NOT NULL COMMENT 'Location plant is moved to',
  `startDateTime` datetime NOT NULL COMMENT 'Date and time plant entered this location',
  `endDateTime` datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  `moveReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for movement',
  `moveReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation for movement',
  `plantLocationNotes` text DEFAULT NULL COMMENT 'Additional notes about this placement',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`plantLocationHistoryId`),
  KEY `locationId` (`locationId`),
  KEY `plantId` (`plantId`),
  CONSTRAINT `plantlocationhistory_ibfk_1` FOREIGN KEY (`locationId`) REFERENCES `location` (`locationId`),
  CONSTRAINT `plantlocationhistory_ibfk_2` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantLocationHistoryDateOrder` CHECK (`endDateTime` is null or `endDateTime` > `startDateTime`),
  CONSTRAINT `chkPlantLocationHistoryIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_plh_single_open_before_insert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN

    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN

        IF EXISTS (

            SELECT 1

            FROM plantlocationhistory

            WHERE plantId = NEW.plantId

              AND isActive = 1

              AND endDateTime IS NULL

        ) THEN

            SIGNAL SQLSTATE '45000'

                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';

        END IF;

    END IF;

END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_plh_single_open_before_update` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN

    
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN

        IF EXISTS (

            SELECT 1

            FROM plantlocationhistory

            WHERE plantId = NEW.plantId

              AND isActive = 1

              AND endDateTime IS NULL

              AND plantLocationHistoryId <> OLD.plantLocationHistoryId

        ) THEN

            SIGNAL SQLSTATE '45000'

                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';

        END IF;

    END IF;

END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantphoto` (
  `plantPhotoId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for this plant photo record',
  `plantEventId` int(11) NOT NULL COMMENT 'Observation event this photo is attached to',
  `plantId` int(11) NOT NULL COMMENT 'Plant this photo belongs to (denormalised for direct access)',
  `fileName` varchar(255) NOT NULL COMMENT 'Stored file name on disk',
  `thumbnailFileName` varchar(255) DEFAULT NULL,
  `legacyFilePath` varchar(500) DEFAULT NULL,
  `mimeType` varchar(100) NOT NULL COMMENT 'MIME content type of the stored file (e.g. image/jpeg)',
  `isHero` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = this photo is the plant hero image; at most one active hero per plant',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active record; 0 = logically removed (soft delete)',
  `heroPlantId` int(11) GENERATED ALWAYS AS (case when `isHero` = 1 and `isActive` = 1 then `plantId` else NULL end) STORED COMMENT 'Helper column used to enforce single active hero photo per plant',
  PRIMARY KEY (`plantPhotoId`),
  UNIQUE KEY `uxPlantPhotoSingleHero` (`heroPlantId`),
  KEY `plantId` (`plantId`),
  KEY `plantEventId` (`plantEventId`),
  CONSTRAINT `plantphoto_ibfk_1` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `plantphoto_ibfk_2` FOREIGN KEY (`plantEventId`) REFERENCES `plantevent` (`plantEventId`),
  CONSTRAINT `chkPlantPhotoIsHero` CHECK (`isHero` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Photo metadata for Observation events. Image binaries are stored on disk; this table stores metadata only. Each photo belongs to exactly one plantEvent and one plant. At most one active hero photo per plant is permitted.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantsplit` (
  `plantSplitId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  `parentPlantId` int(11) NOT NULL COMMENT 'Original plant that was split',
  `splitReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  `splitReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation of why the plant was split',
  `splitNotes` text DEFAULT NULL COMMENT 'Additional notes about the split outcome',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `splitDateTime` datetime NOT NULL COMMENT 'Date and time the split occurred',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active record; 0 = logically removed (soft delete)',
  PRIMARY KEY (`plantSplitId`),
  KEY `parentPlantId` (`parentPlantId`),
  CONSTRAINT `plantsplit_ibfk_1` FOREIGN KEY (`parentPlantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantSplitIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantsplitchild` (
  `plantSplitChildId` int(11) NOT NULL AUTO_INCREMENT,
  `plantSplitId` int(11) NOT NULL,
  `childPlantId` int(11) NOT NULL COMMENT 'New plant created from the split',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  PRIMARY KEY (`plantSplitChildId`),
  UNIQUE KEY `uxPlantSplitChild_childPlantId` (`childPlantId`),
  KEY `ixPlantSplitChild_splitId` (`plantSplitId`),
  CONSTRAINT `chkPlantSplitChildIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `repotting` (
  `repottingId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for repotting event',
  `plantId` int(11) NOT NULL COMMENT 'Plant that was repotted',
  `repotDate` datetime NOT NULL,
  `oldMediumNotes` text DEFAULT NULL COMMENT 'Notes on previous medium condition',
  `newMediumNotes` text DEFAULT NULL COMMENT 'Notes on new medium',
  `potSize` varchar(50) DEFAULT NULL COMMENT 'Pot size used',
  `repotReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for repotting',
  `repotReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation for repotting',
  `repottingNotes` text DEFAULT NULL COMMENT 'Additional repotting notes',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `oldGrowthMediumId` int(11) DEFAULT NULL COMMENT 'Foreign key to growthmedium.growthMediumId representing the old growth medium used before repotting',
  `newGrowthMediumId` int(11) NOT NULL,
  PRIMARY KEY (`repottingId`),
  KEY `newGrowthMediumId` (`newGrowthMediumId`),
  KEY `oldGrowthMediumId` (`oldGrowthMediumId`),
  KEY `plantId` (`plantId`),
  CONSTRAINT `repotting_ibfk_1` FOREIGN KEY (`newGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `repotting_ibfk_2` FOREIGN KEY (`oldGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `repotting_ibfk_3` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkRepottingIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Repotting history per plant.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `schemaversion` (
  `versionId` int(11) NOT NULL AUTO_INCREMENT,
  `scriptName` varchar(255) NOT NULL,
  `checksum` char(64) NOT NULL,
  `appliedAt` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`versionId`),
  UNIQUE KEY `uq_scriptName` (`scriptName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `taxon` (
  `taxonId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for species or hybrid',
  `genusId` int(11) NOT NULL COMMENT 'Foreign key to genus.genusId (taxonomic genus)',
  `speciesName` varchar(100) DEFAULT NULL COMMENT 'Species epithet (NULL for hybrids)',
  `hybridName` varchar(150) DEFAULT NULL COMMENT 'Registered hybrid name (NULL if unnamed or species)',
  `growthCode` varchar(30) DEFAULT NULL COMMENT 'Structured growth habit code',
  `growthNotes` text DEFAULT NULL COMMENT 'Free-text notes about growth characteristics',
  `taxonNotes` text DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 Indicates this taxon represents the current accepted classification for assignments; 0 Indicates inactive taxa remaining historically valid and must not be deleted',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `genusOnlyKey` int(11) GENERATED ALWAYS AS (case when `speciesName` is null and `hybridName` is null then `genusId` else NULL end) STORED,
  `genusSpeciesKey` varchar(255) GENERATED ALWAYS AS (case when `speciesName` is not null then concat(`genusId`,_utf8mb4':',`speciesName`) else NULL end) STORED,
  `genusHybridKey` varchar(255) GENERATED ALWAYS AS (case when `hybridName` is not null then concat(`genusId`,_utf8mb4':',`hybridName`) else NULL end) STORED,
  `isSystemManaged` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 Indicates this taxon row is created and managed by the system and must not be edited by end users; 0 Indicates user-managed taxon records',
  PRIMARY KEY (`taxonId`),
  UNIQUE KEY `uxTaxon_GenusOnly` (`genusOnlyKey`),
  UNIQUE KEY `uxTaxon_GenusSpecies` (`genusSpeciesKey`),
  UNIQUE KEY `uxTaxon_GenusHybrid` (`genusHybridKey`),
  KEY `ixTaxonIsActive` (`isActive`),
  KEY `genusId` (`genusId`),
  CONSTRAINT `taxon_ibfk_1` FOREIGN KEY (`genusId`) REFERENCES `genus` (`genusId`),
  CONSTRAINT `chkTaxon_Shape` CHECK (`speciesName` is null and `hybridName` is null or `speciesName` is not null and `hybridName` is null or `speciesName` is null and `hybridName` is not null),
  CONSTRAINT `chkTaxonIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Taxonomic information for orchid species and hybrids.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `taxonphoto` (
  `taxonPhotoId` int(11) NOT NULL AUTO_INCREMENT,
  `taxonId` int(11) NOT NULL,
  `fileName` varchar(255) NOT NULL,
  `thumbnailFileName` varchar(255) NOT NULL,
  `mimeType` varchar(100) NOT NULL,
  `isPrimary` tinyint(1) NOT NULL DEFAULT 1,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`taxonPhotoId`),
  KEY `taxonId` (`taxonId`),
  CONSTRAINT `taxonphoto_ibfk_1` FOREIGN KEY (`taxonId`) REFERENCES `taxon` (`taxonId`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `testoutoforder` (
  `id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vlocationactivelist` AS SELECT
 1 AS `locationId`,
  1 AS `locationName`,
  1 AS `locationTypeCode`,
  1 AS `climateCode` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantactivecurrentlocation` AS SELECT
 1 AS `plantId`,
  1 AS `taxonId`,
  1 AS `plantTag`,
  1 AS `plantName`,
  1 AS `genusName`,
  1 AS `genusIsActive`,
  1 AS `taxonIsActive`,
  1 AS `locationId`,
  1 AS `locationName`,
  1 AS `locationTypeCode`,
  1 AS `locationStartDateTime`,
  1 AS `displayName`,
  1 AS `heroFileName`,
  1 AS `heroThumbnailFileName` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantactivesummary` AS SELECT
 1 AS `plantId`,
  1 AS `taxonId`,
  1 AS `plantTag`,
  1 AS `plantName`,
  1 AS `acquisitionDate`,
  1 AS `acquisitionSource`,
  1 AS `genusName`,
  1 AS `genusIsActive`,
  1 AS `taxonIsActive`,
  1 AS `speciesName`,
  1 AS `hybridName`,
  1 AS `displayName` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantcurrentgrowthmedium` AS SELECT
 1 AS `plantId`,
  1 AS `growthMediumId`,
  1 AS `growthMediumName`,
  1 AS `potSize`,
  1 AS `repottingNotes`,
  1 AS `repotDate` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantcurrentlocation` AS SELECT
 1 AS `plantLocationHistoryId`,
  1 AS `plantId`,
  1 AS `locationId`,
  1 AS `locationName`,
  1 AS `locationTypeCode`,
  1 AS `locationStartDateTime`,
  1 AS `plantTag`,
  1 AS `plantName`,
  1 AS `taxonId`,
  1 AS `genusName`,
  1 AS `genusIsActive`,
  1 AS `displayName`,
  1 AS `plantEndDate`,
  1 AS `RowOrder` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantlifecyclehistory` AS SELECT
 1 AS `plantId`,
  1 AS `eventDateTime`,
  1 AS `eventType`,
  1 AS `eventSummary`,
  1 AS `sourceTable`,
  1 AS `sourceId` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantsplitchildren` AS SELECT
 1 AS `parentPlantId`,
  1 AS `childPlantId`,
  1 AS `plantTag`,
  1 AS `acquisitionDate` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantstatus` AS SELECT
 1 AS `plantId`,
  1 AS `acquisitionDate`,
  1 AS `acquisitionSource`,
  1 AS `endDate`,
  1 AS `plantTag`,
  1 AS `displayName`,
  1 AS `taxonIsActive`,
  1 AS `genusIsActive`,
  1 AS `locationName`,
  1 AS `lastFloweringDate`,
  1 AS `lastRepotDate`,
  1 AS `currentGrowthMediumName`,
  1 AS `lastFeedDateTime`,
  1 AS `lastFeedTypeDisplayName`,
  1 AS `hasParent`,
  1 AS `parentPlantId`,
  1 AS `parentPlantTag`,
  1 AS `hasChildren` */;
SET character_set_client = @saved_cs_client;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vtaxonidentity` AS SELECT
 1 AS `taxonId`,
  1 AS `genusId`,
  1 AS `genusName`,
  1 AS `genusIsActive`,
  1 AS `speciesName`,
  1 AS `hybridName`,
  1 AS `displayName`,
  1 AS `taxonNotes`,
  1 AS `isActive`,
  1 AS `isSystemManaged`,
  1 AS `growthCode`,
  1 AS `growthNotes` */;
SET character_set_client = @saved_cs_client;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fnGeneratePlantTag`() RETURNS char(8) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci
    READS SQL DATA
BEGIN

    DECLARE vEntropy CHAR(64);

    DECLARE vPrefix VARCHAR(2);

    DECLARE vDigit INT;

    DECLARE vBlock INT;

    DECLARE vChecksum INT;

    DECLARE vCandidate CHAR(8);

    DECLARE vPrefixCount INT;

    DECLARE vOffset INT;

    DECLARE vAttempts INT DEFAULT 0;

    SELECT COUNT(*) INTO vPrefixCount

    FROM phoneticprefix

    WHERE isActive = 1;

    IF vPrefixCount = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'No active phonetic prefixes configured';

    END IF;

    generation_loop: LOOP

        SET vAttempts = vAttempts + 1;

        IF vAttempts > 1000 THEN

            SIGNAL SQLSTATE '45000'

                SET MESSAGE_TEXT = 'Unable to generate unique plantTag after 1000 attempts';

        END IF;

        SET vEntropy = SHA2(UUID(), 256);

        SET vOffset = CONV(SUBSTRING(vEntropy, 1, 8), 16, 10) MOD vPrefixCount;

        SELECT prefix INTO vPrefix

        FROM phoneticprefix

        WHERE isActive = 1

        ORDER BY prefix

        LIMIT vOffset, 1;

        SET vDigit = CONV(SUBSTRING(vEntropy, 9, 2), 16, 10) MOD 10;

        SET vBlock = CONV(SUBSTRING(vEntropy, 11, 8), 16, 10) MOD 1000;

        SET vChecksum = (

            (

                ASCII(SUBSTRING(vPrefix,1,1)) +

                ASCII(SUBSTRING(vPrefix,2,1)) +

                vDigit +

                FLOOR(vBlock / 100) +

                FLOOR((vBlock % 100) / 10) +

                (vBlock % 10)

            ) MOD 10

        );

        SET vCandidate = CONCAT(

            vPrefix,

            vDigit,

            '-',

            LPAD(vBlock, 3, '0'),

            vChecksum

        );

        IF NOT EXISTS (

            SELECT 1

            FROM plant

            WHERE plantTag = vCandidate

        ) THEN

            RETURN vCandidate;

        END IF;

    END LOOP;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spAddGenus`(
    IN pGenusName   VARCHAR(100),
    IN pGenusNotes  TEXT
)
BEGIN
    DECLARE vGenusName VARCHAR(100);
    DECLARE vGenusNotes TEXT;
    DECLARE vGenusId INT;
    DECLARE vGenusOnlyTaxonId INT;

    DECLARE v_errno INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;

        IF v_errno = 1062 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Genus already exists';
        ELSE
            ROLLBACK;
            RESIGNAL;
        END IF;
    END;

    SET vGenusName = NULLIF(TRIM(pGenusName), '');
    SET vGenusNotes = NULLIF(TRIM(pGenusNotes), '');

    IF vGenusName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus name must be provided';
    END IF;

    START TRANSACTION;

    IF EXISTS (
        SELECT 1
        FROM genus
        WHERE genusName =
              vGenusName
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus already exists';
    END IF;

    INSERT INTO genus (
        genusName,
        genusNotes,
        isActive
    )
    VALUES (
        vGenusName,
        vGenusNotes,
        1
    );

    SET vGenusId = LAST_INSERT_ID();

    CALL spAddTaxonInternal(
        vGenusId,
        NULL,
        NULL,
        NULL,
        NULL,
        1,
        vGenusOnlyTaxonId
    );

    COMMIT;

    SELECT
        vGenusId AS GenusId,
        vGenusOnlyTaxonId AS GenusOnlyTaxonId;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spAddLocation`(

    IN pLocationName VARCHAR(100),

    IN pLocationTypeCode VARCHAR(30),

    IN pLocationNotes TEXT,

    IN pClimateCode VARCHAR(30),

    IN pClimateNotes TEXT,

    IN pLocationGeneralNotes TEXT

)
BEGIN

    DECLARE vName VARCHAR(100);

    SET vName = NULLIF(TRIM(pLocationName), '');

    IF vName IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Location name is required.';

    END IF;

    IF CHAR_LENGTH(vName) > 100 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Location name is too long.';

    END IF;

    IF EXISTS (

        SELECT 1

        FROM location

        WHERE LOWER(locationName) = LOWER(vName)

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'A location with this name already exists.';

    END IF;

    INSERT INTO location (

        locationName,

        locationTypeCode,

        locationNotes,

        climateCode,

        climateNotes,

        locationGeneralNotes

    )

    VALUES (

        vName,

        NULLIF(TRIM(pLocationTypeCode), ''),

        NULLIF(TRIM(pLocationNotes), ''),

        NULLIF(TRIM(pClimateCode), ''),

        NULLIF(TRIM(pClimateNotes), ''),

        NULLIF(TRIM(pLocationGeneralNotes), '')

    );

    SELECT LAST_INSERT_ID() AS locationId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spAddPlant`(

    IN pTaxonId INT,

    IN pAcquisitionDate DATETIME,

    IN pAcquisitionSource VARCHAR(150),

    IN pPlantName VARCHAR(100),

    IN pPlantNotes TEXT

)
BEGIN

    DECLARE vTaxonIsActive TINYINT;

    DECLARE vGenusIsActive TINYINT;

    DECLARE vPlantTag CHAR(8);

    DECLARE vPlantId INT;

    IF pTaxonId IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'TaxonId is required';

    END IF;

    SELECT

        t.isActive,

        g.isActive

    INTO

        vTaxonIsActive,

        vGenusIsActive

    FROM taxon t

    JOIN genus g ON t.genusId = g.genusId

    WHERE t.taxonId = pTaxonId;

    IF vTaxonIsActive IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Taxon not found';

    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid';

    END IF;

    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';

    END IF;

    SET vPlantTag = fnGeneratePlantTag();

    SET pPlantName = NULLIF(TRIM(pPlantName), '');

    SET pAcquisitionSource = NULLIF(TRIM(pAcquisitionSource), '');

    SET pPlantNotes = NULLIF(TRIM(pPlantNotes), '');

    INSERT INTO plant (

        taxonId,

        plantTag,

        plantName,

        acquisitionDate,

        acquisitionSource,

        plantNotes,

        isActive,

        endDate,

        endReasonCode,

        endNotes

    )

    VALUES (

        pTaxonId,

        vPlantTag,

        pPlantName,

        CASE

            WHEN pAcquisitionDate IS NULL THEN NULL

            ELSE TIMESTAMP(DATE(pAcquisitionDate), TIME(NOW()))

        END,

        pAcquisitionSource,

        pPlantNotes,

        1,

        NULL,

        NULL,

        NULL

    );

    SET vPlantId = LAST_INSERT_ID();

    SELECT

        vPlantId AS plantId,

        vPlantTag AS plantTag;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spAddTaxon`(

    IN  pGenusId      INT,

    IN  pSpeciesName  VARCHAR(100),

    IN  pHybridName   VARCHAR(150),

    IN  pGrowthNotes  TEXT,

    IN  pTaxonNotes   TEXT

)
BEGIN

    DECLARE vSpeciesName VARCHAR(100);

    DECLARE vHybridName  VARCHAR(150);

    DECLARE vNewTaxonId  INT;



    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');

    SET vHybridName  = NULLIF(TRIM(pHybridName), '');



    CALL spAddTaxonInternal(

        pGenusId,

        vSpeciesName,

        vHybridName,

        pGrowthNotes,

        pTaxonNotes,

        0,

        vNewTaxonId

    );



    SELECT vNewTaxonId AS TaxonId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spAddTaxonInternal`(

    IN  pGenusId            INT,

    IN  pSpeciesName        VARCHAR(100),

    IN  pHybridName         VARCHAR(150),

    IN  pGrowthNotes        TEXT,

    IN  pTaxonNotes         TEXT,

    IN  pIsSystemManaged    TINYINT(1),

    OUT pTaxonId            INT

)
BEGIN

    DECLARE vGenusIsActive TINYINT;

    DECLARE vSpeciesName VARCHAR(100);

    DECLARE vHybridName  VARCHAR(150);

    DECLARE vGrowthNotes TEXT;

    DECLARE vTaxonNotes  TEXT;

    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');

    SET vHybridName  = NULLIF(TRIM(pHybridName), '');

    SET vGrowthNotes = NULLIF(TRIM(pGrowthNotes), '');

    SET vTaxonNotes  = NULLIF(TRIM(pTaxonNotes), '');

    SELECT isActive

    INTO vGenusIsActive

    FROM genus

    WHERE genusId = pGenusId;

    IF vGenusIsActive IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Invalid genusId: genus does not exist';

    END IF;

    IF vGenusIsActive = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Taxon must be created under an active genus.';

    END IF;

    INSERT INTO taxon (

        genusId,

        speciesName,

        hybridName,

        growthNotes,

        taxonNotes,

        isSystemManaged

    )

    VALUES (

        pGenusId,

        vSpeciesName,

        vHybridName,

        vGrowthNotes,

        vTaxonNotes,

        pIsSystemManaged

    );

    SET pTaxonId = LAST_INSERT_ID();

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spEditPlantLocation`(
    IN pPlantLocationHistoryId INT,
    IN pNewStartDateTime DATETIME,
    IN pMoveReasonNotes VARCHAR(500),
    IN pPlantLocationNotes VARCHAR(500)
)
BEGIN
    DECLARE vPlantId INT;
    DECLARE vOldStart DATETIME;
    DECLARE vOldEnd DATETIME;
    DECLARE vIsCurrent TINYINT;

    DECLARE vPrevId INT;
    DECLARE vPrevStart DATETIME;

    DECLARE vNextStart DATETIME;

    DECLARE vNewStart DATETIME;
    DECLARE vEffectiveEnd DATETIME;

    START TRANSACTION;


        SELECT plantId, startDateTime, endDateTime
          INTO vPlantId, vOldStart, vOldEnd
        FROM plantlocationhistory
        WHERE plantLocationHistoryId = pPlantLocationHistoryId
          AND isActive = 1
        FOR UPDATE;

        IF vPlantId IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Active location history row not found.';
        END IF;

        SET vIsCurrent = IF(vOldEnd IS NULL, 1, 0);
        SET vNewStart = COALESCE(pNewStartDateTime, vOldStart);
        SET vEffectiveEnd = IF(vIsCurrent = 1, NOW(), vOldEnd);


        IF vNewStart >= vEffectiveEnd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime must be earlier than endDateTime.';
        END IF;


        SELECT plantLocationHistoryId, startDateTime
          INTO vPrevId, vPrevStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND endDateTime = vOldStart
          AND plantLocationHistoryId <> pPlantLocationHistoryId
        FOR UPDATE;


        SELECT startDateTime
          INTO vNextStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND startDateTime > vOldStart
        ORDER BY startDateTime
        LIMIT 1
        FOR UPDATE;


        IF vNextStart IS NOT NULL AND vNewStart >= vNextStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot overlap next location.';
        END IF;


        IF vIsCurrent = 1 AND vNewStart >= NOW() THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot be in the future.';
        END IF;


        IF vPrevId IS NOT NULL AND vNewStart <= vPrevStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime would invalidate previous location.';
        END IF;


        IF vPrevId IS NOT NULL AND vNewStart <> vOldStart THEN
            UPDATE plantlocationhistory
            SET endDateTime = vNewStart
            WHERE plantLocationHistoryId = vPrevId;
        END IF;


        UPDATE plantlocationhistory
        SET
            startDateTime      = vNewStart,
            moveReasonNotes    = COALESCE(pMoveReasonNotes, moveReasonNotes),
            plantLocationNotes = COALESCE(pPlantLocationNotes, plantLocationNotes)
        WHERE plantLocationHistoryId = pPlantLocationHistoryId;


        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple current locations.';
        END IF;

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spGetPlantLineage`(

    IN pPlantId INT

)
BEGIN

    WITH RECURSIVE lineage AS (



        SELECT

            p.plantId,

            p.plantTag,

            p.acquisitionDate,

            p.endDate,

            0 AS level

        FROM plant p

        WHERE p.plantId = pPlantId

        UNION ALL



        SELECT

            parent.plantId,

            parent.plantTag,

            parent.acquisitionDate,

            parent.endDate,

            l.level - 1

        FROM lineage l

        JOIN plantsplitchild psc

            ON psc.childPlantId = l.plantId

        JOIN plantsplit ps

            ON ps.plantSplitId = psc.plantSplitId

        JOIN plant parent

            ON parent.plantId = ps.parentPlantId



        WHERE l.level > -20

    )

    SELECT

        plantId,

        plantTag,

        acquisitionDate,

        endDate,

        level

    FROM lineage

    ORDER BY level DESC;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spMovePlantToLocation`(
    IN pPlantId INT,
    IN pLocationId INT,
    IN pStartDate DATE,

    IN pMoveReasonNotes VARCHAR(500),
    IN pPlantLocationNotes VARCHAR(500)
)
BEGIN
    DECLARE vStart DATETIME;
    DECLARE vNow DATETIME;

    DECLARE vCurrentId INT;
    DECLARE vCurrentLocationId INT;
    DECLARE vCurrentStart DATETIME;

    DECLARE vLatestPoint DATETIME;
    DECLARE vOverlapCount INT;

    SET vNow = NOW();
    SET vStart = TIMESTAMP(DATE(pStartDate), TIME(vNow));



    IF NOT EXISTS (SELECT 1 FROM plant WHERE plantId = pPlantId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PlantId does not exist.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM location WHERE locationId = pLocationId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LocationId does not exist.';
    END IF;


    SELECT plantLocationHistoryId, locationId, startDateTime
      INTO vCurrentId, vCurrentLocationId, vCurrentStart
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1
      AND endDateTime IS NULL
    LIMIT 1;

    IF vCurrentId IS NOT NULL AND vCurrentLocationId = pLocationId THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant is already in this location.';
    END IF;

    IF vCurrentId IS NOT NULL AND vStart < vCurrentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move start cannot be earlier than current location start.';
    END IF;

    SELECT MAX(COALESCE(endDateTime, startDateTime))
      INTO vLatestPoint
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1;

    IF vLatestPoint IS NOT NULL AND vStart < vLatestPoint THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move would backdate into existing history.';
    END IF;

    SELECT COUNT(*) INTO vOverlapCount
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1
      AND plantLocationHistoryId <> COALESCE(vCurrentId, -1)
      AND startDateTime < vStart
      AND COALESCE(endDateTime, '9999-12-31') > vStart;

    IF vOverlapCount > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move would overlap existing history.';
    END IF;



    START TRANSACTION;

        IF vCurrentId IS NOT NULL THEN
            UPDATE plantlocationhistory
            SET endDateTime = vStart
            WHERE plantLocationHistoryId = vCurrentId
              AND isActive = 1
              AND endDateTime IS NULL;
        END IF;

        INSERT INTO plantlocationhistory (
            plantId,
            locationId,
            startDateTime,
            endDateTime,

            moveReasonNotes,
            plantLocationNotes,
            isActive
        )
        VALUES (
            pPlantId,
            pLocationId,
            vStart,
            NULL,

            pMoveReasonNotes,
            pPlantLocationNotes,
            1
        );

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spRemovePlantLocation`(
    IN pPlantLocationHistoryId INT
)
BEGIN
    DECLARE vPlantId INT;
    DECLARE vStart DATETIME;
    DECLARE vEnd DATETIME;
    DECLARE vIsCurrent TINYINT;

    DECLARE vPrevId INT;
    DECLARE vNextId INT;

    START TRANSACTION;



        SELECT plantId, startDateTime, endDateTime
          INTO vPlantId, vStart, vEnd
        FROM plantlocationhistory
        WHERE plantLocationHistoryId = pPlantLocationHistoryId
          AND isActive = 1
        FOR UPDATE;

        IF vPlantId IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Active location history row not found.';
        END IF;

        SET vIsCurrent = IF(vEnd IS NULL, 1, 0);



        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime = vStart
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ambiguous previous location during removal.';
        END IF;

        SELECT plantLocationHistoryId
          INTO vPrevId
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND endDateTime = vStart
        LIMIT 1;



        IF vIsCurrent = 0 AND (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND startDateTime = vEnd
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ambiguous next location during removal.';
        END IF;

        IF vIsCurrent = 0 THEN
            SELECT plantLocationHistoryId
              INTO vNextId
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND startDateTime = vEnd
            LIMIT 1;
        END IF;



        UPDATE plantlocationhistory
        SET isActive = 0
        WHERE plantLocationHistoryId = pPlantLocationHistoryId;

        IF vIsCurrent = 1 THEN
            IF vPrevId IS NOT NULL THEN
                UPDATE plantlocationhistory
                SET endDateTime = NULL
                WHERE plantLocationHistoryId = vPrevId;
            END IF;
        ELSE
            IF vPrevId IS NOT NULL AND vNextId IS NOT NULL THEN
                UPDATE plantlocationhistory
                SET endDateTime = vEnd
                WHERE plantLocationHistoryId = vPrevId;
            END IF;
        END IF;



        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation after location removal.';
        END IF;

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spSetGenusActiveState`(

    IN pGenusId INT,

    IN pIsActive TINYINT

)
BEGIN

    DECLARE vCurrentState TINYINT;

    DECLARE vExists INT;

    IF pGenusId IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'GenusId is required.';

    END IF;

    IF pIsActive NOT IN (0,1) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Invalid value provided.';

    END IF;

    SELECT COUNT(*) INTO vExists

    FROM genus

    WHERE genusId = pGenusId;

    IF vExists = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Genus not found.';

    END IF;

    SELECT isActive

    INTO vCurrentState

    FROM genus

    WHERE genusId = pGenusId;

    IF vCurrentState = pIsActive THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'No change required.';

    END IF;

    UPDATE genus

    SET isActive = pIsActive

    WHERE genusId = pGenusId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spSetHeroPhoto`(
    IN pPlantId INT,
    IN pPlantPhotoId INT
)
BEGIN

    DECLARE vExists INT;


    SELECT COUNT(*)
    INTO vExists
    FROM orchids.plantphoto
    WHERE plantPhotoId = pPlantPhotoId
      AND plantId = pPlantId
      AND isActive = 1;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid hero selection';
    END IF;


    UPDATE orchids.plantphoto
    SET isHero = 0
    WHERE plantId = pPlantId
      AND isHero = 1
      AND isActive = 1;


    UPDATE orchids.plantphoto
    SET isHero = 1
    WHERE plantPhotoId = pPlantPhotoId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spSetLocationActiveState`(
    IN pLocationId INT,
    IN pIsActive TINYINT
)
BEGIN

    DECLARE vCurrentState TINYINT;
    DECLARE vExists INT;

    IF pLocationId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'LocationId is required.';
    END IF;

    IF pIsActive NOT IN (0,1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid value provided.';
    END IF;

    SELECT COUNT(*) INTO vExists
    FROM location
    WHERE locationId = pLocationId;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location not found.';
    END IF;

    SELECT isActive
    INTO vCurrentState
    FROM location
    WHERE locationId = pLocationId;

    IF vCurrentState = pIsActive THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No change required.';
    END IF;



    UPDATE location
    SET isActive = pIsActive
    WHERE locationId = pLocationId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spSetTaxonActiveState`(
    IN pTaxonId INT,
    IN pIsActive BOOLEAN
)
proc: BEGIN

    DECLARE vCurrentState BOOLEAN;
    DECLARE vIsSystemManaged BOOLEAN;

    SELECT isActive, isSystemManaged
    INTO vCurrentState, vIsSystemManaged
    FROM taxon
    WHERE taxonId = pTaxonId;

    IF vCurrentState IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Taxon not found';
    END IF;

    IF vIsSystemManaged = 1 AND pIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'System-managed records cannot be deactivated';
    END IF;

    IF vCurrentState = pIsActive THEN
        LEAVE proc;
    END IF;

    UPDATE taxon
    SET isActive = pIsActive
    WHERE taxonId = pTaxonId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spSplitPlant`(

    IN pParentPlantId INT,

    IN pSplitDateTime DATETIME,

    IN pChildrenJson JSON,

    IN pSplitReasonNotes TEXT,

    IN pSplitNotes TEXT

)
BEGIN

    DECLARE vTaxonId INT;

    DECLARE vParentPlantTag CHAR(8);

    DECLARE vParentStart DATETIME;

    DECLARE vParentEnd DATETIME;

    DECLARE vTaxonIsActive TINYINT;

    DECLARE vGenusIsActive TINYINT;

    DECLARE vSplitId INT;

    DECLARE vChildCount INT;

    DECLARE vIdx INT DEFAULT 0;

    DECLARE vChildName VARCHAR(100);

    DECLARE vMediumIdText VARCHAR(20);

    DECLARE vMediumId INT;

    DECLARE vChildTag CHAR(8);

    DECLARE vChildPlantId INT;







    IF pParentPlantId IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Parent plant id is required';

    END IF;

    IF pSplitDateTime IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'SplitDateTime is required';

    END IF;

    IF DATE(pSplitDateTime) > CURRENT_DATE THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Split date cannot be in the future';

    END IF;

    IF JSON_LENGTH(pChildrenJson) < 2 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Split must create at least two child plants';

    END IF;

    START TRANSACTION;

    SELECT

        p.taxonId,

        p.plantTag,

        p.acquisitionDate,

        p.endDate,

        t.isActive,

        g.isActive

    INTO

        vTaxonId,

        vParentPlantTag,

        vParentStart,

        vParentEnd,

        vTaxonIsActive,

        vGenusIsActive

    FROM plant p

    JOIN taxon t ON p.taxonId = t.taxonId

    JOIN genus g ON t.genusId = g.genusId

    WHERE p.plantId = pParentPlantId

      AND p.isActive = 1

    FOR UPDATE;

    IF vParentEnd IS NOT NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Parent plant already ended';

    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid';

    END IF;

    IF pSplitDateTime < vParentStart THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Split datetime cannot be before plant lifecycle start';

    END IF;

    IF EXISTS (

        SELECT 1

        FROM plantsplit

        WHERE parentPlantId = pParentPlantId

          AND isActive = 1

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Plant has already been split';

    END IF;







    INSERT INTO plantsplit (

        parentPlantId,

        splitDateTime,

        splitReasonNotes,

        splitNotes,

        isActive

    )

    VALUES (

        pParentPlantId,

        pSplitDateTime,

        pSplitReasonNotes,

        pSplitNotes,

        1

    );

    SET vSplitId = LAST_INSERT_ID();

    SET vChildCount = JSON_LENGTH(pChildrenJson);





    DROP TEMPORARY TABLE IF EXISTS tmpChildren;

    CREATE TEMPORARY TABLE tmpChildren (

        childPlantId INT,

        childPlantTag CHAR(8)

    );

    WHILE vIdx < vChildCount DO

        SET vChildName = JSON_UNQUOTE(

            JSON_EXTRACT(pChildrenJson, CONCAT('$[', vIdx, '].plantName'))

        );

        IF vChildName IS NOT NULL THEN

            SET vChildName = TRIM(vChildName);

            IF vChildName = '' OR LOWER(vChildName) = 'null' THEN

                SET vChildName = NULL;

            END IF;

        END IF;

        SET vMediumIdText = JSON_UNQUOTE(

            JSON_EXTRACT(

                pChildrenJson,

                CONCAT('$[', vIdx, '].mediumId')

            )

        );

        IF vMediumIdText IS NULL OR vMediumIdText = 'null' THEN

            SET vMediumId = NULL;

        ELSE

            SET vMediumId = CAST(vMediumIdText AS UNSIGNED);

        END IF;

        SET vChildTag = fnGeneratePlantTag();

        INSERT INTO plant (

            taxonId,

            plantTag,

            plantName,

            acquisitionDate,

            acquisitionSource,

            isActive

        )

        VALUES (

            vTaxonId,

            vChildTag,

            vChildName,

            pSplitDateTime,

            CONCAT('Split from ', vParentPlantTag),

            1

        );

        SET vChildPlantId = LAST_INSERT_ID();

        IF vMediumId IS NOT NULL THEN

            INSERT INTO repotting (

                plantId,

                repotDate,

                newGrowthMediumId,

                repotReasonNotes,

                isActive

            )

            VALUES (

                vChildPlantId,

                pSplitDateTime,

                vMediumId,

                'Initial medium from split',

                1

            );

        END IF;

        INSERT INTO plantsplitchild (

            plantSplitId,

            childPlantId,

            isActive

        )

        VALUES (

            vSplitId,

            vChildPlantId,

            1

        );

        INSERT INTO tmpChildren VALUES (vChildPlantId, vChildTag);

        SET vIdx = vIdx + 1;

    END WHILE;







    IF vParentEnd IS NULL THEN

        UPDATE plantlocationhistory

        SET endDateTime = pSplitDateTime

        WHERE plantId = pParentPlantId

        AND endDateTime IS NULL

        AND isActive = 1;

        UPDATE flowering

        SET endDate = pSplitDateTime

        WHERE plantId = pParentPlantId

        AND endDate IS NULL

        AND isActive = 1;

    END IF;

    UPDATE plant

    SET endDate = pSplitDateTime,

        endNotes = CONCAT(

            'Split into ',

            vChildCount,

            ' plants on ',

            DATE_FORMAT(pSplitDateTime, '%d/%m/%Y')

        )

    WHERE plantId = pParentPlantId;

    SELECT childPlantId, childPlantTag

    FROM tmpChildren;

    DROP TEMPORARY TABLE tmpChildren;

    COMMIT;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spUpdateGenus`(

    IN pGenusId INT,

    IN pGenusName VARCHAR(100),

    IN pGenusNotes TEXT

)
BEGIN

    DECLARE vName VARCHAR(100);

    DECLARE vNotes TEXT;

    DECLARE v_errno INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION

    BEGIN

        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;

        ROLLBACK;

        IF v_errno = 1062 THEN

            SIGNAL SQLSTATE '45000'

                SET MESSAGE_TEXT = 'Genus already exists';

        ELSE

            RESIGNAL;

        END IF;

    END;

    SET vName = NULLIF(TRIM(pGenusName), '');

    SET vNotes = NULLIF(TRIM(pGenusNotes), '');

    IF vName IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Genus name must be provided';

    END IF;

    START TRANSACTION;

    IF NOT EXISTS (

        SELECT 1

        FROM genus

        WHERE genusId = pGenusId

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Genus not found';

    END IF;

    IF EXISTS (

        SELECT 1

        FROM genus

        WHERE genusName =

              vName

          AND genusId <> pGenusId

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Genus already exists';

    END IF;

    UPDATE genus

    SET

        genusName = vName,

        genusNotes = vNotes

    WHERE genusId = pGenusId;

    COMMIT;

    SELECT pGenusId AS GenusId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spUpdateGrowthMediumDetails`(

    IN pGrowthMediumId INT,

    IN pName VARCHAR(100),

    IN pDescription VARCHAR(500)

)
BEGIN

    DECLARE vName VARCHAR(100);

    IF pGrowthMediumId IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Growth medium id is required.';

    END IF;

    SET vName = NULLIF(TRIM(pName), '');

    IF vName IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Growth medium name is required.';

    END IF;

    IF NOT EXISTS (

        SELECT 1

        FROM growthmedium

        WHERE growthMediumId = pGrowthMediumId

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Growth medium not found.';

    END IF;

    IF EXISTS (

        SELECT 1

        FROM growthmedium

        WHERE name = vName

          AND growthMediumId <> pGrowthMediumId

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'A growth medium with this name already exists.';

    END IF;

    UPDATE growthmedium

    SET

        name = vName,

        description = NULLIF(TRIM(pDescription), '')

    WHERE growthMediumId = pGrowthMediumId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spUpdateLocationDetails`(

    IN pLocationId INT,

    IN pLocationName VARCHAR(100),

    IN pLocationTypeCode VARCHAR(30),

    IN pLocationNotes TEXT,

    IN pClimateCode VARCHAR(30),

    IN pClimateNotes TEXT,

    IN pLocationGeneralNotes TEXT

)
BEGIN

    DECLARE vName VARCHAR(100);

    DECLARE vExists INT;

    IF pLocationId IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'LocationId is required.';

    END IF;

    SET vName = NULLIF(TRIM(pLocationName), '');

    IF vName IS NULL THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Location name is required.';

    END IF;

    SELECT COUNT(*) INTO vExists

    FROM location

    WHERE locationId = pLocationId;

    IF vExists = 0 THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Location not found.';

    END IF;

    IF EXISTS (

        SELECT 1

        FROM location

        WHERE LOWER(locationName) = LOWER(vName)

        AND locationId <> pLocationId

    ) THEN

        SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'A location with this name already exists.';

    END IF;

    UPDATE location

    SET

        locationName = vName,

        locationTypeCode = NULLIF(TRIM(pLocationTypeCode), ''),

        locationNotes = NULLIF(TRIM(pLocationNotes), ''),

        climateCode = NULLIF(TRIM(pClimateCode), ''),

        climateNotes = NULLIF(TRIM(pClimateNotes), ''),

        locationGeneralNotes = NULLIF(TRIM(pLocationGeneralNotes), '')

    WHERE locationId = pLocationId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spUpdatePlantDetails`(

    IN pPlantId INT,

    IN pTaxonId INT,

    IN pPlantName VARCHAR(100),

    IN pAcquisitionDate DATETIME,

    IN pAcquisitionSource VARCHAR(150),

    IN pEndDate DATETIME,

    IN pEndNotes TEXT,

    IN pPlantNotes TEXT

)
BEGIN

    DECLARE vExistingAcquisitionDate DATETIME;

    DECLARE vExistingEndDate DATETIME;

    DECLARE vIsSplitChild BOOLEAN;

    DECLARE vIsSplitParent BOOLEAN;

    DECLARE vFinalAcquisitionDate DATETIME;

    DECLARE vFinalEndDate DATETIME;

    SELECT acquisitionDate, endDate

      INTO vExistingAcquisitionDate, vExistingEndDate

      FROM plant

     WHERE plantId = pPlantId

     FOR UPDATE;

    IF ROW_COUNT() = 0 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'Plant not found.';

    END IF;

    SELECT EXISTS (

        SELECT 1 FROM plantsplitchild

        WHERE childPlantId = pPlantId

    ) INTO vIsSplitChild;

    SELECT EXISTS (

        SELECT 1 FROM plantsplit

        WHERE parentPlantId = pPlantId

    ) INTO vIsSplitParent;



    IF (DATE(pAcquisitionDate) <=> DATE(vExistingAcquisitionDate)) = 0 THEN

        IF vIsSplitChild THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Cannot modify acquisition date: plant was created via split.';

        END IF;

    END IF;



    IF (DATE(pEndDate) <=> DATE(vExistingEndDate)) = 0 THEN

        IF vIsSplitParent THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Cannot modify end date: plant has been split.';

        END IF;

    END IF;



    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';

    END IF;



    IF pEndDate IS NOT NULL AND DATE(pEndDate) > CURRENT_DATE THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'End date cannot be in the future.';

    END IF;



    IF pEndDate IS NOT NULL AND pAcquisitionDate IS NOT NULL

       AND DATE(pEndDate) <= DATE(pAcquisitionDate) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'End date must be after acquisition date.';

    END IF;

    SET vFinalAcquisitionDate =

        CASE

            WHEN pAcquisitionDate IS NULL THEN NULL



            WHEN vExistingAcquisitionDate IS NULL THEN

                TIMESTAMP(DATE(pAcquisitionDate), CURRENT_TIME)



            ELSE

                TIMESTAMP(DATE(pAcquisitionDate), TIME(vExistingAcquisitionDate))

        END;

    SET vFinalEndDate =

        CASE

            WHEN pEndDate IS NULL THEN NULL



            WHEN vExistingEndDate IS NULL THEN

                TIMESTAMP(DATE(pEndDate), CURRENT_TIME)



            ELSE

                TIMESTAMP(DATE(pEndDate), TIME(vExistingEndDate))

        END;

    UPDATE plant

       SET taxonId = pTaxonId,

           plantName = pPlantName,

           acquisitionDate = vFinalAcquisitionDate,

           acquisitionSource = pAcquisitionSource,

           endDate = vFinalEndDate,

           endNotes = pEndNotes,

           plantNotes = pPlantNotes

     WHERE plantId = pPlantId;

    IF vExistingEndDate IS NULL AND vFinalEndDate IS NOT NULL THEN



        UPDATE plantlocationhistory

           SET endDateTime = vFinalEndDate

         WHERE plantId = pPlantId

           AND endDateTime IS NULL;



        UPDATE flowering

           SET endDateTime = vFinalEndDate

         WHERE plantId = pPlantId

           AND endDateTime IS NULL;

    END IF;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `spUpdateTaxonDetails`(

    IN p_taxonId INT,

    IN p_speciesName VARCHAR(100),

    IN p_hybridName VARCHAR(150),

    IN p_growthCode VARCHAR(30),

    IN p_growthNotes TEXT,

    IN p_taxonNotes TEXT

)
BEGIN

    DECLARE v_isSystemManaged TINYINT;

    DECLARE v_existingSpecies VARCHAR(100);

    DECLARE v_existingHybrid VARCHAR(150);

    SET p_speciesName = NULLIF(TRIM(p_speciesName), '');

    SET p_hybridName  = NULLIF(TRIM(p_hybridName), '');

    SELECT isSystemManaged, speciesName, hybridName

    INTO v_isSystemManaged, v_existingSpecies, v_existingHybrid

    FROM taxon

    WHERE taxonId = p_taxonId;

    IF v_isSystemManaged IS NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'Taxon not found';

    END IF;

    START TRANSACTION;

    IF v_isSystemManaged = 1 THEN

        UPDATE taxon

        SET

            growthCode  = p_growthCode,

            growthNotes = p_growthNotes,

            taxonNotes  = p_taxonNotes

        WHERE taxonId = p_taxonId;

    ELSE



        IF v_existingSpecies IS NOT NULL AND p_hybridName IS NOT NULL THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Species taxon cannot be converted to hybrid';

        END IF;

        IF v_existingHybrid IS NOT NULL AND p_speciesName IS NOT NULL THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Hybrid taxon cannot be converted to species';

        END IF;

        IF p_speciesName IS NULL AND p_hybridName IS NULL THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Taxon must have either species or hybrid name';

        END IF;

        IF p_speciesName IS NOT NULL AND p_hybridName IS NOT NULL THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Taxon cannot have both species and hybrid names';

        END IF;



        IF p_speciesName IS NOT NULL AND EXISTS (

            SELECT 1

            FROM taxon

            WHERE speciesName = p_speciesName

              AND taxonId <> p_taxonId

        ) THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Species already exists';

        END IF;

        IF p_hybridName IS NOT NULL AND EXISTS (

            SELECT 1

            FROM taxon

            WHERE hybridName = p_hybridName

              AND taxonId <> p_taxonId

        ) THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Hybrid already exists';

        END IF;

        UPDATE taxon

        SET

            speciesName = p_speciesName,

            hybridName  = p_hybridName,

            growthCode  = p_growthCode,

            growthNotes = p_growthNotes,

            taxonNotes  = p_taxonNotes

        WHERE taxonId = p_taxonId;

    END IF;

    COMMIT;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50001 DROP VIEW IF EXISTS `vlocationactivelist`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vlocationactivelist` AS select `location`.`locationId` AS `locationId`,`location`.`locationName` AS `locationName`,`location`.`locationTypeCode` AS `locationTypeCode`,`location`.`climateCode` AS `climateCode` from `location` where `location`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantactivecurrentlocation`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantactivecurrentlocation` AS select `p`.`plantId` AS `plantId`,`t`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`t`.`isActive` AS `taxonIsActive`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end AS `displayName`,`pp`.`fileName` AS `heroFileName`,`pp`.`thumbnailFileName` AS `heroThumbnailFileName` from (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (select `sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime` from (select `lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc) AS `RowOrder` from `plantlocationhistory` `lochistory` where `lochistory`.`isActive` = 1) `sub` where `sub`.`RowOrder` = 1) `plh` on(`p`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) left join `plantphoto` `pp` on(`pp`.`plantId` = `p`.`plantId` and `pp`.`isHero` = 1 and `pp`.`isActive` = 1)) where `p`.`isActive` = 1 and `p`.`endDate` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantactivesummary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantactivesummary` AS select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`s`.`isActive` AS `taxonIsActive`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,case when `s`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `s`.`speciesName` is not null then concat(`g`.`genusName`,' ',`s`.`speciesName`) when `s`.`hybridName` is not null then concat(`g`.`genusName`,' ',`s`.`hybridName`) else `g`.`genusName` end AS `displayName` from ((`plant` `p` join `taxon` `s` on(`s`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `s`.`genusId`)) where `p`.`isActive` = 1 and `p`.`endDate` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantcurrentgrowthmedium`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantcurrentgrowthmedium` AS select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `repotting`.`repottingId` AS `repottingId`,`repotting`.`plantId` AS `plantId`,`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`repotting`.`potSize` AS `potSize`,`repotting`.`repottingNotes` AS `repottingNotes`,`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `repotting`.`plantId` order by `repotting`.`repotDate` desc,`repotting`.`repottingId` desc) AS `rn` from `repotting` where `repotting`.`isActive` = 1) `r` join `growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantcurrentlocation`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantcurrentlocation` AS select `plh`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`plant`.`plantId` AS `plantId`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,`plant`.`plantTag` AS `plantTag`,`plant`.`plantName` AS `plantName`,`taxon`.`taxonId` AS `taxonId`,`genus`.`genusName` AS `genusName`,`genus`.`isActive` AS `genusIsActive`,case when `taxon`.`isSystemManaged` = 1 then concat(`genus`.`genusName`,' sp.') when `taxon`.`speciesName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`speciesName`) when `taxon`.`hybridName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`hybridName`) else `genus`.`genusName` end AS `displayName`,`plant`.`endDate` AS `plantEndDate`,`plh`.`RowOrder` AS `RowOrder` from ((((`plant` join `taxon` on(`taxon`.`taxonId` = `plant`.`taxonId`)) join `genus` on(`genus`.`genusId` = `taxon`.`genusId`)) left join (select `sub`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`endDateTime` AS `endDateTime`,`sub`.`moveReasonCode` AS `moveReasonCode`,`sub`.`moveReasonNotes` AS `moveReasonNotes`,`sub`.`plantLocationNotes` AS `plantLocationNotes`,`sub`.`createdDateTime` AS `createdDateTime`,`sub`.`isActive` AS `isActive`,`sub`.`updatedDateTime` AS `updatedDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,`lochistory`.`endDateTime` AS `endDateTime`,`lochistory`.`moveReasonCode` AS `moveReasonCode`,`lochistory`.`moveReasonNotes` AS `moveReasonNotes`,`lochistory`.`plantLocationNotes` AS `plantLocationNotes`,`lochistory`.`createdDateTime` AS `createdDateTime`,`lochistory`.`isActive` AS `isActive`,`lochistory`.`updatedDateTime` AS `updatedDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc) AS `RowOrder` from `plantlocationhistory` `lochistory` where `lochistory`.`isActive` = 1) `sub` where `sub`.`RowOrder` = 1) `plh` on(`plant`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) where `plant`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantlifecyclehistory`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantlifecyclehistory` AS with plant_identity as (select `p`.`plantId` AS `plantId` from `plant` `p` where `p`.`isActive` = 1)select `pi`.`plantId` AS `plantId`,`pe`.`eventDateTime` AS `eventDateTime`,'Observation' collate utf8mb4_unicode_ci AS `eventType`,`pe`.`eventDetails` collate utf8mb4_unicode_ci AS `eventSummary`,'plantevent' collate utf8mb4_unicode_ci AS `sourceTable`,`pe`.`plantEventId` AS `sourceId` from (`plant_identity` `pi` join `plantevent` `pe` on(`pe`.`plantId` = `pi`.`plantId`)) where `pe`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,cast(`r`.`repotDate` as datetime) AS `eventDateTime`,'Repotting' collate utf8mb4_unicode_ci AS `eventType`,concat('Repotted',case when `r`.`oldGrowthMediumId` is not null and `r`.`newGrowthMediumId` is not null then concat(' FROM ',`oldgm`.`name`,' to ',`newgm`.`name`) when `r`.`oldGrowthMediumId` is not null then concat(' FROM ',`oldgm`.`name`) when `r`.`newGrowthMediumId` is not null then concat(' into ',`newgm`.`name`) else '' end,case when coalesce(nullif(`r`.`repottingNotes`,''),nullif(`r`.`repotReasonNotes`,''),nullif(`r`.`newMediumNotes`,''),nullif(`r`.`oldMediumNotes`,'')) is not null then concat(' - ',coalesce(nullif(`r`.`repottingNotes`,''),nullif(`r`.`repotReasonNotes`,''),nullif(`r`.`newMediumNotes`,''),nullif(`r`.`oldMediumNotes`,''))) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'repotting' collate utf8mb4_unicode_ci AS `sourceTable`,`r`.`repottingId` AS `sourceId` from (((`plant_identity` `pi` join `repotting` `r` on(`r`.`plantId` = `pi`.`plantId`)) left join `growthmedium` `oldgm` on(`r`.`oldGrowthMediumId` = `oldgm`.`growthMediumId`)) left join `growthmedium` `newgm` on(`r`.`newGrowthMediumId` = `newgm`.`growthMediumId`)) where `r`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,cast(`f`.`startDate` as datetime) AS `eventDateTime`,'Flowering' collate utf8mb4_unicode_ci AS `eventType`,concat('Flowered',case when `f`.`startDate` is not null and `f`.`endDate` is not null then concat(' FROM ',date_format(`f`.`startDate`,'%d-%m-%Y'),' to ',date_format(`f`.`endDate`,'%d-%m-%Y')) when `f`.`startDate` is not null and `f`.`endDate` is null then concat(' FROM ',date_format(`f`.`startDate`,'%d-%m-%Y'),' (currently flowering)') else '' end,case when `f`.`flowerCount` is not null and `f`.`spikeCount` is not null then concat(' with ',if(`f`.`flowerCount` = 1,'1 flower',concat(`f`.`flowerCount`,' flowers')),' over ',if(`f`.`spikeCount` = 1,'1 spike',concat(`f`.`spikeCount`,' spikes'))) when `f`.`flowerCount` is not null then concat(' with ',if(`f`.`flowerCount` = 1,'1 flower',concat(`f`.`flowerCount`,' flowers'))) when `f`.`spikeCount` is not null then concat(' over ',if(`f`.`spikeCount` = 1,'1 spike',concat(`f`.`spikeCount`,' spikes'))) else '' end,case when `f`.`floweringNotes` is not null and `f`.`floweringNotes` <> '' then concat(' - ',`f`.`floweringNotes`) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'flowering' collate utf8mb4_unicode_ci AS `sourceTable`,`f`.`floweringId` AS `sourceId` from (`plant_identity` `pi` join `flowering` `f` on(`f`.`plantId` = `pi`.`plantId`)) where `f`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,`plh`.`startDateTime` AS `eventDateTime`,'LocationChange' collate utf8mb4_unicode_ci AS `eventType`,concat('Moved to ',`l`.`locationName`,' on ',date_format(`plh`.`startDateTime`,'%d-%m-%Y'),case when `plh`.`endDateTime` is not null then concat(' to ',date_format(`plh`.`endDateTime`,'%d-%m-%Y')) else ' (current)' end,case when `plh`.`moveReasonNotes` is not null and `plh`.`moveReasonNotes` <> '' then concat(' : ',`plh`.`moveReasonNotes`) else '' end,case when `plh`.`plantLocationNotes` is not null and `plh`.`plantLocationNotes` <> '' then concat(' - ',`plh`.`plantLocationNotes`) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'plantlocationhistory' collate utf8mb4_unicode_ci AS `sourceTable`,`plh`.`plantLocationHistoryId` AS `sourceId` from ((`plant_identity` `pi` join `plantlocationhistory` `plh` on(`plh`.`plantId` = `pi`.`plantId`)) join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) where `plh`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantsplitchildren`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantsplitchildren` AS select `ps`.`parentPlantId` AS `parentPlantId`,`child`.`plantId` AS `childPlantId`,`child`.`plantTag` AS `plantTag`,`child`.`acquisitionDate` AS `acquisitionDate` from ((`plantsplit` `ps` join `plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vplantstatus`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantstatus` AS select `p`.`plantId` AS `plantId`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`p`.`endDate` AS `endDate`,`p`.`plantTag` AS `plantTag`,trim(case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end) AS `displayName`,`t`.`isActive` AS `taxonIsActive`,`g`.`isActive` AS `genusIsActive`,`l`.`locationName` AS `locationName`,`lf`.`startDate` AS `lastFloweringDate`,`lr`.`repotDate` AS `lastRepotDate`,`gm`.`name` AS `currentGrowthMediumName`,`lfeed`.`eventDateTime` AS `lastFeedDateTime`,`ot`.`displayName` AS `lastFeedTypeDisplayName`,case when `psc`.`plantSplitChildId` is not null then 1 else 0 end AS `hasParent`,`ps`.`parentPlantId` AS `parentPlantId`,`parent`.`plantTag` AS `parentPlantTag`,case when `children`.`plantSplitId` is not null then 1 else 0 end AS `hasChildren` from (((((((((((((`plant` `p` left join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) left join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join `plantlocationhistory` `clh` on(`clh`.`plantLocationHistoryId` = (select `plh`.`plantLocationHistoryId` from `plantlocationhistory` `plh` where `plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 order by `plh`.`startDateTime` desc limit 1))) left join `location` `l` on(`l`.`locationId` = `clh`.`locationId`)) left join `flowering` `lf` on(`lf`.`floweringId` = (select `f`.`floweringId` from `flowering` `f` where `f`.`plantId` = `p`.`plantId` and `f`.`isActive` = 1 order by `f`.`startDate` desc limit 1))) left join `repotting` `lr` on(`lr`.`repottingId` = (select `r`.`repottingId` from `repotting` `r` where `r`.`plantId` = `p`.`plantId` and `r`.`isActive` = 1 order by `r`.`repotDate` desc limit 1))) left join `growthmedium` `gm` on(`gm`.`growthMediumId` = `lr`.`newGrowthMediumId`)) left join `plantevent` `lfeed` on(`lfeed`.`plantEventId` = (select `pe`.`plantEventId` from (`plantevent` `pe` join `observationtype` `o` on(`o`.`Id` = `pe`.`observationTypeId` and `o`.`isActive` = 1 and `o`.`typeCode` like 'OBS_FEED%')) where `pe`.`plantId` = `p`.`plantId` and `pe`.`isActive` = 1 order by `pe`.`eventDateTime` desc limit 1))) left join `observationtype` `ot` on(`ot`.`Id` = `lfeed`.`observationTypeId`)) left join `plantsplitchild` `psc` on(`p`.`plantId` = `psc`.`childPlantId`)) left join `plantsplit` `ps` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) left join `plant` `parent` on(`ps`.`parentPlantId` = `parent`.`plantId`)) left join `plantsplit` `children` on(`p`.`plantId` = `children`.`parentPlantId`)) where `p`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vtaxonidentity`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vtaxonidentity` AS select `t`.`taxonId` AS `taxonId`,`t`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`t`.`speciesName` AS `speciesName`,`t`.`hybridName` AS `hybridName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is null and `t`.`hybridName` is null then `g`.`genusName` when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) else concat(`g`.`genusName`,' ',`t`.`hybridName`) end AS `displayName`,`t`.`taxonNotes` AS `taxonNotes`,`t`.`isActive` AS `isActive`,`t`.`isSystemManaged` AS `isSystemManaged`,`t`.`growthCode` AS `growthCode`,`t`.`growthNotes` AS `growthNotes` from (`taxon` `t` join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

