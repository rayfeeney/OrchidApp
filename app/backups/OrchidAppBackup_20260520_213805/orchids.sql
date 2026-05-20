/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.16-MariaDB, for Win64 (AMD64)
--
-- Host: 127.0.0.1    Database: orchids
-- ------------------------------------------------------
-- Server version	10.11.16-MariaDB

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

--
-- Current Database: `orchids`
--

/*!40000 DROP DATABASE IF EXISTS `orchids`*/;

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `orchids` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;

USE `orchids`;

--
-- Table structure for table `flowering`
--

DROP TABLE IF EXISTS `flowering`;
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
  KEY `ixFloweringPlantStartDate` (`plantId`,`startDate`),
  KEY `ixFlowerStatusLookup` (`plantId`,`isActive`,`startDate` DESC),
  CONSTRAINT `fkFloweringPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkFloweringIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `flowering`
--

LOCK TABLES `flowering` WRITE;
/*!40000 ALTER TABLE `flowering` DISABLE KEYS */;
/*!40000 ALTER TABLE `flowering` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `genus`
--

DROP TABLE IF EXISTS `genus`;
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

--
-- Dumping data for table `genus`
--

LOCK TABLES `genus` WRITE;
/*!40000 ALTER TABLE `genus` DISABLE KEYS */;
/*!40000 ALTER TABLE `genus` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `growthmedium`
--

DROP TABLE IF EXISTS `growthmedium`;
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

--
-- Dumping data for table `growthmedium`
--

LOCK TABLES `growthmedium` WRITE;
/*!40000 ALTER TABLE `growthmedium` DISABLE KEYS */;
/*!40000 ALTER TABLE `growthmedium` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `location`
--

DROP TABLE IF EXISTS `location`;
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

--
-- Dumping data for table `location`
--

LOCK TABLES `location` WRITE;
/*!40000 ALTER TABLE `location` DISABLE KEYS */;
/*!40000 ALTER TABLE `location` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `observationtype`
--

DROP TABLE IF EXISTS `observationtype`;
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
  UNIQUE KEY `uxObservationType_TypeCode` (`typeCode`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Defines subtypes of Observation records. System rows may drive application behaviour.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `observationtype`
--

LOCK TABLES `observationtype` WRITE;
/*!40000 ALTER TABLE `observationtype` DISABLE KEYS */;
INSERT INTO `observationtype` VALUES
(1,'OBS_NOTE','Note','Observation containing written notes only',1,1,'2026-05-06 18:12:32',NULL),
(2,'OBS_PHOTO','Photo','Observation containing one or more photos',1,1,'2026-05-06 18:12:32',NULL),
(3,'OBS_FEED_GROWTH','Growth Feed','Feeding - growth fertiliser',1,1,'2026-05-06 18:12:32',NULL),
(4,'OBS_FEED_BLOOM','Bloom Feed','Feeding - bloom fertiliser',1,1,'2026-05-06 18:12:32',NULL);
/*!40000 ALTER TABLE `observationtype` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `phoneticprefix`
--

DROP TABLE IF EXISTS `phoneticprefix`;
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

--
-- Dumping data for table `phoneticprefix`
--

LOCK TABLES `phoneticprefix` WRITE;
/*!40000 ALTER TABLE `phoneticprefix` DISABLE KEYS */;
/*!40000 ALTER TABLE `phoneticprefix` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plant`
--

DROP TABLE IF EXISTS `plant`;
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
  KEY `fkPlantTaxon` (`taxonId`),
  CONSTRAINT `fkPlantTaxon` FOREIGN KEY (`taxonId`) REFERENCES `taxon` (`taxonId`),
  CONSTRAINT `chkPlantIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orchid plants tracked in the collection.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plant`
--

LOCK TABLES `plant` WRITE;
/*!40000 ALTER TABLE `plant` DISABLE KEYS */;
/*!40000 ALTER TABLE `plant` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plantevent`
--

DROP TABLE IF EXISTS `plantevent`;
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
  KEY `ixPlantEventPlantDateTime` (`plantId`,`eventDateTime`),
  KEY `ixPlantEventStatusLookup` (`plantId`,`isActive`,`eventDateTime` DESC,`observationTypeId`),
  KEY `fkPlantEventObservationType` (`observationTypeId`),
  CONSTRAINT `fkPlantEventObservationType` FOREIGN KEY (`observationTypeId`) REFERENCES `observationtype` (`Id`),
  CONSTRAINT `fkPlantEventPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantEventIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='General-purpose event log for plant care and observations.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantevent`
--

LOCK TABLES `plantevent` WRITE;
/*!40000 ALTER TABLE `plantevent` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantevent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plantlocationhistory`
--

DROP TABLE IF EXISTS `plantlocationhistory`;
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
  KEY `ixPlantLocationHistoryPlantTime` (`plantId`,`startDateTime`,`endDateTime`),
  KEY `ixPlantLocationHistoryLocationTime` (`locationId`,`startDateTime`,`endDateTime`),
  KEY `ixPlhStatusLookup` (`plantId`,`isActive`,`startDateTime` DESC,`locationId`),
  CONSTRAINT `fkPlantLocationHistoryLocation` FOREIGN KEY (`locationId`) REFERENCES `location` (`locationId`),
  CONSTRAINT `fkPlantLocationHistoryPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantLocationHistoryDateOrder` CHECK (`endDateTime` is null or `endDateTime` > `startDateTime`),
  CONSTRAINT `chkPlantLocationHistoryIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantlocationhistory`
--

LOCK TABLES `plantlocationhistory` WRITE;
/*!40000 ALTER TABLE `plantlocationhistory` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantlocationhistory` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`orchid`@`localhost`*/ /*!50003 TRIGGER `trgPlantLocationHistoryBeforeInsert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN

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
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`orchid`@`localhost`*/ /*!50003 TRIGGER `trgPlantLocationHistoryBeforeUpdate` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN

    
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

--
-- Table structure for table `plantphoto`
--

DROP TABLE IF EXISTS `plantphoto`;
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
  KEY `fkPlantPhotoPlant` (`plantId`),
  KEY `fkPlantPhotoPlantEvent` (`plantEventId`),
  CONSTRAINT `fkPlantPhotoPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `fkPlantPhotoPlantEvent` FOREIGN KEY (`plantEventId`) REFERENCES `plantevent` (`plantEventId`),
  CONSTRAINT `chkPlantPhotoIsHero` CHECK (`isHero` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Photo metadata for Observation events. Image binaries are stored on disk; this table stores metadata only. Each photo belongs to exactly one plantEvent and one plant. At most one active hero photo per plant is permitted.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantphoto`
--

LOCK TABLES `plantphoto` WRITE;
/*!40000 ALTER TABLE `plantphoto` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantphoto` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plantpropagation`
--

DROP TABLE IF EXISTS `plantpropagation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantpropagation` (
  `plantPropagationId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant propagation lineage record',
  `parentPlantId` int(11) NOT NULL COMMENT 'Original plant used for propagation',
  `childPlantId` int(11) NOT NULL COMMENT 'New plant created from propagation',
  `propagationTypeId` int(11) NOT NULL COMMENT 'Propagation type: keiki, backbulb, cutting',
  `propagationDateTime` datetime NOT NULL COMMENT 'Date and time the propagation occurred',
  `propagationNotes` text DEFAULT NULL COMMENT 'Free-text notes about the propagation',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active record; 0 = logically removed (soft delete)',
  PRIMARY KEY (`plantPropagationId`),
  UNIQUE KEY `uxPlantPropagation_childPlantId` (`childPlantId`),
  KEY `fkPlantPropagation_parentPlantId` (`parentPlantId`),
  KEY `fkPlantPropagation_propagationTypeId` (`propagationTypeId`),
  CONSTRAINT `fkPlantPropagation_childPlantId` FOREIGN KEY (`childPlantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `fkPlantPropagation_parentPlantId` FOREIGN KEY (`parentPlantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `fkPlantPropagation_propagationTypeId` FOREIGN KEY (`propagationTypeId`) REFERENCES `propagationtype` (`propagationTypeId`),
  CONSTRAINT `chkPlantPropagationIsActive` CHECK (`isActive` in (0,1)),
  CONSTRAINT `chkPlantPropagationDifferentPlants` CHECK (`parentPlantId` <> `childPlantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantpropagation`
--

LOCK TABLES `plantpropagation` WRITE;
/*!40000 ALTER TABLE `plantpropagation` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantpropagation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plantsplit`
--

DROP TABLE IF EXISTS `plantsplit`;
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
  UNIQUE KEY `uxPlantSplit_parentPlantId` (`parentPlantId`),
  CONSTRAINT `fkPlantSplitParent` FOREIGN KEY (`parentPlantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkPlantSplitIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantsplit`
--

LOCK TABLES `plantsplit` WRITE;
/*!40000 ALTER TABLE `plantsplit` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantsplit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plantsplitchild`
--

DROP TABLE IF EXISTS `plantsplitchild`;
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
  KEY `fkPlantSplitChildSplit` (`plantSplitId`),
  CONSTRAINT `fkPlantSplitChildPlant` FOREIGN KEY (`childPlantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `fkPlantSplitChildSplit` FOREIGN KEY (`plantSplitId`) REFERENCES `plantsplit` (`plantSplitId`),
  CONSTRAINT `chkPlantSplitChildIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plantsplitchild`
--

LOCK TABLES `plantsplitchild` WRITE;
/*!40000 ALTER TABLE `plantsplitchild` DISABLE KEYS */;
/*!40000 ALTER TABLE `plantsplitchild` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `propagationtype`
--

DROP TABLE IF EXISTS `propagationtype`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `propagationtype` (
  `propagationTypeId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for propagation type',
  `propagationTypeCode` varchar(30) NOT NULL COMMENT 'Stable system code (KEIKI, BACKBULB, CUTTING)',
  `propagationTypeName` varchar(100) NOT NULL COMMENT 'Display name',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active; 0 = inactive',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`propagationTypeId`),
  UNIQUE KEY `uxPropagationType_code` (`propagationTypeCode`),
  CONSTRAINT `chkPropagationTypeIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `propagationtype`
--

LOCK TABLES `propagationtype` WRITE;
/*!40000 ALTER TABLE `propagationtype` DISABLE KEYS */;
/*!40000 ALTER TABLE `propagationtype` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `repotting`
--

DROP TABLE IF EXISTS `repotting`;
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
  KEY `ixRepottingPlantRepotDate` (`plantId`,`repotDate`),
  KEY `ixRepotStatusLookup` (`plantId`,`isActive`,`repotDate` DESC,`newGrowthMediumId`),
  KEY `fkRepottingNewGrowthMedium` (`newGrowthMediumId`),
  KEY `fkRepottingOldGrowthMedium` (`oldGrowthMediumId`),
  CONSTRAINT `fkRepottingNewGrowthMedium` FOREIGN KEY (`newGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `fkRepottingOldGrowthMedium` FOREIGN KEY (`oldGrowthMediumId`) REFERENCES `growthmedium` (`growthMediumId`),
  CONSTRAINT `fkRepottingPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`),
  CONSTRAINT `chkRepottingIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Repotting history per plant.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `repotting`
--

LOCK TABLES `repotting` WRITE;
/*!40000 ALTER TABLE `repotting` DISABLE KEYS */;
/*!40000 ALTER TABLE `repotting` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schemaversion`
--

DROP TABLE IF EXISTS `schemaversion`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `schemaversion` (
  `versionId` int(11) NOT NULL AUTO_INCREMENT,
  `scriptName` varchar(255) NOT NULL,
  `checksum` char(64) NOT NULL,
  `appliedAt` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`versionId`),
  UNIQUE KEY `uq_scriptName` (`scriptName`)
) ENGINE=InnoDB AUTO_INCREMENT=235 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schemaversion`
--

LOCK TABLES `schemaversion` WRITE;
/*!40000 ALTER TABLE `schemaversion` DISABLE KEYS */;
INSERT INTO `schemaversion` VALUES
(1,'baseline','baseline','2026-05-06 18:12:32'),
(2,'202602152206_AddObservationSystemTypes.sql','4B70F8DCDCF3864DB3CBC76B112825ABE2EBA02AF409707A728C57F6CB7EB994','2026-05-06 18:12:32'),
(3,'202602171812_DropPlantSplitConstraints.sql','6D44760711E8F881262068FE3D43B4384FB07D09E45514A76D28213F756C8D11','2026-05-06 18:12:32'),
(4,'202602171816_DropPlantSplitFields.sql','75A10B3C8A783986E82276A6534FA386CA32E52E5215ED8AE8CA5DD88E4F879B','2026-05-06 18:12:32'),
(5,'202602171822_AddPlantSplitFields.sql','C0EDF0BD15E1AC801F338FD512866458D3946FD740F2F80902D4002976EF8014','2026-05-06 18:12:32'),
(6,'202602171824_AddPlantSplitConstraints.sql','87E8D96ADDEFB307299C5962E31BB77E4ACF65459488A3520A0839CB2F1FAF72','2026-05-06 18:12:32'),
(7,'202602171827_CreatePlantSplitChild.sql','9C28558160F9F87C377968C6BAAB6E3263ADB488EC9CAF8776A31BB450E3C209','2026-05-06 18:12:32'),
(8,'202602172023_CreateSpSplitPlant.sql','66A8749B0ED9402371B38A5658A078D2E595DA9DE73FFDE05E98D6E722680AB9','2026-05-06 18:12:32'),
(9,'202602172219_AlterPlant.sql','7A67D7CEA5946A025B91189D2D911A5C88D4BBEE1CF8C1C335748A1EE32BEBB3','2026-05-06 18:12:32'),
(10,'202602182031_FixVPlantLifecycleHistoryCollation.sql','B4FE7157F29A771705C438DBD441D503FCE8E92AFCCBFF0ACA5F7FE441F22EE6','2026-05-06 18:12:32'),
(11,'202602182157_RecreateSpSplitPlant.sql','7B569E25C47A7EE684320EDA39A5CE45570A635807D79303F10EB664BFEE85B2','2026-05-06 18:12:32'),
(12,'202602191800_RecreateSpSpiltPlant.sql','1E69237DD816A387776CEBA09B578582425E17948D80628FC20F372A801C12BD','2026-05-06 18:12:32'),
(13,'202602191815_RecreateSpSpiltPlant.sql','34FDAC410C739A119D0FCEAD0D32AD749A47A7D45A9BA2D3E48661249CBA9E6C','2026-05-06 18:12:32'),
(14,'202602191830_RecreateSpSplitPlant.sql','0343B42F227BFC0C4FD6278B7545B470F214F5110C8D795FFCF039C68FAFAA7C','2026-05-06 18:12:32'),
(15,'202602192148_AlterVPlantActiveSummary.sql','7167FE7A31F5DC6A8FFD9E4A7BB3B6777FEE7AECF9E65C723348DA57CC736844','2026-05-06 18:12:32'),
(16,'202602192200_AlterVPlantCurrentLocation.sql','A299E6844D2CCE2861DB99B279E0E2DDDFD2532CB206447C8D16CFCFBF00397B','2026-05-06 18:12:32'),
(17,'202602201200_AlterVPlantCurrentLocation.sql','62875B107F79E3E42C7AA6388F30006734BB523432C4872A8905DD78D551D069','2026-05-06 18:12:32'),
(18,'202602201225_AlterVPlantCurrentLocation.sql','607F71BE793FE68960FC55C761895C569867400CF97C81911140B59E4770E6A0','2026-05-06 18:12:32'),
(19,'202602201436_AddVPlantActiveCurrentLocation.sql','00A8EF52186A0607851509C3F4B23E2585E95B88B1F569909F703EE149CE55C6','2026-05-06 18:12:32'),
(20,'202602201810_RecreateSpSplitPlant.sql','3339F8074D9135B077DC35A215F626DA9D0D863ED983B7B21ED0C21F2F4DC848','2026-05-06 18:12:32'),
(21,'202602202120_CreateSpUpdatePlantDetails.sql','89AE07F670796BDC0A17DEB5E735FFEABCEACED6601B69AF562AB33221C50875','2026-05-06 18:12:32'),
(22,'202602202150_AlterVPlantCurrentLocation.sql','1E0ABA560A2FED300E74814C1E53BFEF2324AEBD8802EC151C832A987E5674C7','2026-05-06 18:12:32'),
(23,'202602210912_AlterVPlantCurrentLocation.sql','607F71BE793FE68960FC55C761895C569867400CF97C81911140B59E4770E6A0','2026-05-06 18:12:32'),
(24,'202602210918_AddVPlantActiveCurrentLocation.sql','95C690578157AB2260BC4D148631FE03F8913282E884BB9021B2A6C06353D9A7','2026-05-06 18:12:32'),
(25,'202602210930_AddVPlantActiveCurrentLocation.sql','601006F8A4867FC47A82C08B91B4DB4894D17879107C02187BAFADDE3E3B482C','2026-05-06 18:12:32'),
(26,'202602210935_AlterVPlantActiveCurrentLocation.sql','CF21B55A16C451F39D6163A9CF7B2925D1C3984E6D217903D3CA073A70B1B3F3','2026-05-06 18:12:32'),
(27,'202602211000_AlterVPlantActiveCurrentLocation.sql','3CC9A740DFAC634BD455CD7AFB540FF06F70D90D8865C50A0760BC65BCEB7126','2026-05-06 18:12:32'),
(28,'202602211420_AlterSpUpdatePlantDetails.sql','89AE07F670796BDC0A17DEB5E735FFEABCEACED6601B69AF562AB33221C50875','2026-05-06 18:12:32'),
(29,'202603011150_UpdatePlantPhotoFkToRestrict.sql','9136D6E948272945A19CAB8ECAD2C90106F0742BEF60E0705422A37AA4716015','2026-05-06 18:12:32'),
(30,'202603011210_AddStructuralCheckConstraints.sql','B18AE8E226FB58A86ED748FDFDA0518F1D0FF7AA967DD83E7CD8344A31EA4848','2026-05-06 18:12:32'),
(31,'202603011300_Alter_plantphoto.sql','1E90326018A6D00E1FB66731170B9F840C6AE8C69BDDBA3B9418A974835EDDFC','2026-05-06 18:12:32'),
(32,'202603041812_CreateSpAddLocation.sql','623A3FA4CAF137A621B5ABF0F0EDE4D045408C683A073177CA57A9A7712A24FF','2026-05-06 18:12:32'),
(33,'202603041819_AddSpUpdateLocation.sql','8CB9514C21B8EC1CBFBBAF69E7841B6E998C89149D552DF3803998BB0DAFC5A4','2026-05-06 18:12:32'),
(34,'202603041825_AddSpSetLocationActiveState.sql','60FE5E69E856F88F555BCF496B042500FC7F104AD0D190B6EA6D422A10FD1001','2026-05-06 18:12:32'),
(35,'202603041832_AddIxLocationActiveName.sql','2A9065215114B6A710F2A2D652ECAE1989E7B0E521B721B9C5E26EB821E95AAA','2026-05-06 18:12:32'),
(36,'202603041836_AddVLocationActiveList.sql','4E4F9065A178A7EEEC485FC17021D3A73FB4880A2B46CC236F16C487ADEA0131','2026-05-06 18:12:32'),
(37,'202603071342_CreateGrowthMedium.sql','A2A44B75486907D8A8D69917D4952672F186C1C8452C73CB8D64BF48F1CA2197','2026-05-06 18:12:32'),
(38,'202603071508_AlterRepotting.sql','9743AAC1265A275B3ADDA936FD31E7B02180F1A7A699DB2CCF82BA6CE873CA6D','2026-05-06 18:12:32'),
(39,'202603071512_AlterVPlantLifecycleHistory.sql','3FBC234B98B670E479CF10FC4187BEC5C97E747BE28F3979753C2E078DE8D433','2026-05-06 18:12:32'),
(40,'202603071527_AlterRepotting.sql','12C6C8CB5107A5BDB7AB6FC541A03710CC6F5F3503485D72ACF899EA97918606','2026-05-06 18:12:32'),
(41,'202603071545_AlterGrowthMedium.sql','F6D4E67A84865EACB172F319EE5C80A224A9C9438D851A38F7949173803E5689','2026-05-06 18:12:32'),
(42,'202603081228_AlterVPlantLifecycleHistory.sql','DAE59F15222E1AF6180F9CEC686D235C1DB3FD3160AB33AB1F4D868CA9293270','2026-05-06 18:12:32'),
(43,'202603081450_StandardiseUtf8mb4.sql','06AF0ADC87E060AD9A83736393C9B63A008907DB5B69A47D0C967F18120F0BDF','2026-05-06 18:12:32'),
(44,'202603081600_RecreateVLocationActiveList.sql','CAC2854248B9A148CC11C8E4DE8A426F2CDB4823BCC506F452D474889969BFC8','2026-05-06 18:12:32'),
(45,'202603081644_RecreateVLocationActiveList.sql','D5ACDA601C36770D1E6C9941B3A2A6D0D7027C3FA3AEE074F9032CD3F515798A','2026-05-06 18:12:32'),
(46,'202603081705_RecreateVPlantActiveCurrentLocation.sql','6E7B427DFD4363D2F60C29CBFCE80CD35C87D8470AAC2E6BE41EAB049988A539','2026-05-06 18:12:32'),
(47,'202603081712_RecreateVPlantActiveSummary.sql','FB558D612B83EB0483DC16D64776849ED075F732AF6AE09E949C8E64F26A2C0B','2026-05-06 18:12:32'),
(48,'202603081718_RecreateVPlantCurrentLocation.sql','FB558D612B83EB0483DC16D64776849ED075F732AF6AE09E949C8E64F26A2C0B','2026-05-06 18:12:32'),
(49,'202603081723_RecreateVPlantLifecycleHistory.sql','109BD4114DA063D97A274ACA3B3141FDAADDB48FEB798CAA121E9755CE879B52','2026-05-06 18:12:32'),
(50,'202603081730_RecreateVTaxonIdentity.sql','74AAE8E0EBD6B69AACC7810C36A4C7566767456F58A59307000A19728049B04E','2026-05-06 18:12:32'),
(51,'202603081740_RecreateSpAddGenus.sql','788C07BBAC488810739ED631117C60ECAC66D9711F3219010B15FD2C058AA14E','2026-05-06 18:12:32'),
(52,'202603081747_RecreateSpAddLocation.sql','90A9CFA418A78510F635888050682666C1736A227BBF9CC8AABE3C4D42C88DA0','2026-05-06 18:12:32'),
(53,'202603081752_RecreateSpAddTaxon.sql','346F51E40BE769EE1471BEA897264769E7E0184278EBB3F7715FC6711B54E311','2026-05-06 18:12:32'),
(54,'202603081756_RecreateSpAddTaxonInternal.sql','8A00BC6ADEC0D567FFB121354728EC7A024D9F7AD433758E1391C79751FC65F3','2026-05-06 18:12:32'),
(55,'202603081800_RecreareSpEditPlantLocation.sql','15FFCEA1599924AB1F6C99D56097CA808CFDD86AD6DF577BD9D3100CC1315048','2026-05-06 18:12:32'),
(56,'202603081804_RecreateSpMovePlantToLocation.sql','6C074ED0376E4B9BBA5F8C009549DE217811D29A403E06408E385427C6732D73','2026-05-06 18:12:32'),
(57,'202603081807_RecreateSpRemovePlantLocation.sql','0C430E76771AC87500A9C9EFEBC46C17BEDF808721C52181ABBF3737E50F7464','2026-05-06 18:12:32'),
(58,'202603081810_RecreateSpSetHeroPhoto.sql','5DFFAE933C3F891994B5FDF3F22661898760B8E353FD49809D50B94480B42521','2026-05-06 18:12:32'),
(59,'202603081816_RecreateSpSetLocationActiveState.sql','4BE605A3ADAD53044376CA5E50D4A6C0998F69EFAC00B5F5FC887CEFCF7BC458','2026-05-06 18:12:32'),
(60,'202603081819_RecreateSpSplitPlant.sql','14F725A00F326ECE556F603C5AB25E4ED91675E156DA0904F86A0A7D00FF2FBF','2026-05-06 18:12:32'),
(61,'202603081822_RecreateSpUpdateLocation.sql','AB576B0F9A176855713AEA939DC89DCA4D64B21FB184FA9FBEFE3FC04276E707','2026-05-06 18:12:32'),
(62,'202603081825_RecreateSpUpdatePlantDetails.sql','63703EBD6B3A3A4BFE7A0BDCC67BD383BFE0D4AE65F73517B96A084AB5D7917C','2026-05-06 18:12:32'),
(63,'202603081832_RecreateVPlantActiveSummary.sql','8968E91A94B438A1FFB65FA4150DAAD3834DCB2FCF3F4F68D9736E4B74F2C77E','2026-05-06 18:12:32'),
(64,'202603091404_CreateSpSetTaxonActiveState.sql','390FC5B55F15A27AF454F2F6629464C1CD942704531E24A1EBD2417FC7050F6C','2026-05-06 18:12:32'),
(65,'202603091637_RecreatespUpdatePlantDetails.sql','873E720557A7D67F918924518CCAC9E250A07D6CC4152D0A80BEED082DA860D0','2026-05-06 18:12:32'),
(66,'202603101318_RecreateSpUpdateGenusMetadata.sql','141FDD2F86FF21640526AA6A5EACB1CF1D6656C677ADABA64C29BD0E43DD0BD8','2026-05-06 18:12:32'),
(67,'202603101323_RecreateSpUpdateTaxonMetadata.sql','F66B4444EABC514ED0B7F331560513A1EC1C25112F0EC8104FC11DB3C7B72DC9','2026-05-06 18:12:32'),
(68,'202603101326_UpdateSpUpdateGenusMetadata.sql','23B651A4A6219714F66D83D23794C2714CDFCAB7CE8F53F2E5CBE958AE0875E2','2026-05-06 18:12:32'),
(69,'202603101356_AlterSpSetTaxonActiveState.sql','6066709B8973DA1ECE521CB4BFF90FB6CD68328D86A9BCFC77D2E15FC2111494','2026-05-06 18:12:32'),
(70,'202603101750_CreateSpUpdateTaxonDetails.sql','2CFB57F0606C8A6644B2C97C86F1121C4060338B0A8CED10560D02A4B04936DF','2026-05-06 18:12:32'),
(71,'202603101844_CreateSpAddGrowthMedium.sql','E2F97847645D3B8DDD6E7AE5CCE239F5BF123436F114AC004418A9408A35F860','2026-05-06 18:12:32'),
(72,'202603101958_CreateSpUpdateGrowthMediumDetails.sql','791CCF9605A79A77EC8DDED5EF84E5FA97E6AE3AED85150AEA9125154E443E3C','2026-05-06 18:12:32'),
(73,'202603102109_CreateSpSetGrowthMediumActiveState.sql','D536A4DCF44003818901067CD88FA89A023E416414EE34E630E1B8C25A3C2FD2','2026-05-06 18:12:32'),
(74,'202603121338_AlterSpSplitPlant.sql','DC16BBBF544A28E423B533AD3A9A65A94C29EA1DBB98AA189593EE951EB7608F','2026-05-06 18:12:32'),
(75,'202603121635_AlterSpAddGenus.sql','066D126803A1F0BD25AF590C7B953E442FEE44131F9EE79C4B02347EB50DAA30','2026-05-06 18:12:32'),
(76,'202603121937_AlterSpAddGenus.sql','521871FE1FEA14DC08768E9BF409202B951C995E852579A5A97223D729255761','2026-05-06 18:12:32'),
(77,'202603122009_CreateSpGenusUpdate.sql','8AFC245D9C54CAC5F2229D238AD61FBDF0D45CA684F97444629395B7EC8E5C72','2026-05-06 18:12:32'),
(78,'202603122022_AlterSpGenusUpdate.sql','ED6AE1757B09B775DDA0DEF5BF155245CCB87481C948131FBA863513C8AAC9AD','2026-05-06 18:12:32'),
(79,'202603122235_DropSpSetGrowthMediumActiveState.sql','88961F05C499EFAA8E8E4AD03190786E998CFCD542FF2BEC5D61B1B37C29BDE8','2026-05-06 18:12:32'),
(80,'202603131728_DropSpUpdateGrowthMediumDetails.sql','650CA4686C7C271FA728269F822D86F4F4971099E0A492254D49C5C794B2F897','2026-05-06 18:12:32'),
(81,'202603131734_DropSpAddGrowthMedium.sql','E2D122A425BF70A7A4924800F13BFC22A999CF958A42492A0E40823E0C3B31A0','2026-05-06 18:12:32'),
(82,'202603131751_AlterSpSetTaxonActiveState.sql','31D6D45CD7A4BE70F8660377665D10E29D262B27ACDC7EAAB93F279730F78623','2026-05-06 18:12:32'),
(83,'202603131822_AlterSpUpdateTaxonDetails.sql','FF5603A50DF074B41843123F85E75CD48D37D41F44456E98378FAC759996DA32','2026-05-06 18:12:32'),
(84,'202603132008_AlterSpAddTaxon.sql','935983BC5296024A6FC494DB430818F2DE281594BEC6816683319789F391C029','2026-05-06 18:12:32'),
(85,'202603132100_AlterSpAddTaxonInternal.sql','FAF690D77FDC9DFBA1070A896489CA8A21D4C58AC0E0EDD5C35F8E7FEB8DECA9','2026-05-06 18:12:32'),
(86,'202603132107_AlterSpAddTaxon.sql','BDF9681E7978B41DB13FB0141BA3B72E25EA10EADEEA08B3A3EB9A936B16874D','2026-05-06 18:12:32'),
(87,'202603132153_AlterSpAddTaxonInternal.sql','20DA6FA67BDD3177881C8E7C246EED41BA236261EF51BF48EDDAD9E363F9823E','2026-05-06 18:12:32'),
(88,'202603140802_AlterSpSetLocationActiveState.sql','130021EFD7B6B87EED18A470CC3ECD89A3E768CB0F1E1FF7F3F3DF1C0683F11D','2026-05-06 18:12:32'),
(89,'202603140816_SpAddLocation.sql','1B068FFB1AC324AAAEC8C211AE713F146591F89B51B41AE16C44FFF090AA48A9','2026-05-06 18:12:32'),
(90,'202603140851_CreateSpUpdateLocationDetails.sql','E09B2B2296AD9491BE39DFA3AF37E0ED76F32A6AEB290C86A9F807D4F7D069D9','2026-05-06 18:12:32'),
(91,'202603140859_AlterSpSetLocationActiveState.sql','09DCDE97AFDDE63841EADAEE159AF597BC3E8843AEAAA58267937073476C0D0C','2026-05-06 18:12:32'),
(92,'202603140903_CreateSpSetGenusActiveState.sql','728B1388DF48BB90BE3B5BDD501DFCAE122096678DAA2B5056DA955D62E6724E','2026-05-06 18:12:32'),
(93,'202603141058_AlterSpSplitPlant.sql','B4022C0FD89371A8E8C75BDFA709C445B89A5AD84830B3B9BC8F7E4FD83BDBA8','2026-05-06 18:12:32'),
(94,'202603141117_AlterSpSplitPlant.sql','C6EF9FF8FDE69D20F9A29D75F4D0C2E0A289181746F134AEFF595A0961026D7F','2026-05-06 18:12:32'),
(95,'202603141236_AlterSpAddTaxonInternal.sql','77922065C89F2AA95C90B20DA729068805197A9D072CFACB4AF9FE6F840BF69F','2026-05-06 18:12:32'),
(96,'202603141404_AlterVTaxonIdentity.sql','6B234C331268DFAA505F9B524684CCB9E1B74C6D2753F1C21BC54CB1AEB233CE','2026-05-06 18:12:32'),
(97,'202603141417_AlterVPlantActiveSummary.sql','CE461AE5E05544F97C5450EFDC36B04F296601A9DA2F4634558FB751F21B4955','2026-05-06 18:12:32'),
(98,'202603141420_AlterVPlantActiveCurrentLocation.sql','37B51B2F8E3DE9F88922A72B0861FB1523EAAC206FD6717D47C302A8A8A2EF08','2026-05-06 18:12:32'),
(99,'202603141426_AlterVPlantCurrentLocation.sql','40A47D1C07BD8234EC86ACBD0D42C1B3EA7CFCB78A5AF16A48D580633CDF82DC','2026-05-06 18:12:32'),
(100,'202603141702_AlterVPlantActiveSummary.sql','2FD0C0FC1499DFF2AC38A899EAC2D33EC892F90C8DF71AE7F227B89D78FB7508','2026-05-06 18:12:32'),
(101,'202603142013_AlterVPlantActiveCurrentLocation.sql','5FC11C8847C254A5374BDEAD7CBB744B2E28B7ED34E90AAC5D27D7421C5105BF','2026-05-06 18:12:32'),
(102,'202603161618_CreateSpUpdateGrowthMediumDetails.sql','14254ADD4A0DA26DFEA3C41DC1771AE1EFF46F7E8ECD1C0D4EF0BEBD870CCA24','2026-05-06 18:12:32'),
(103,'202603161637_CreateSpSetGrowthMediumActiveState.sql','91D57E5891C6695757375B02B38E2F0DAF4DC1E29600975D1B0AD69444BC9C00','2026-05-06 18:12:32'),
(104,'202603191721_CreateSpGeneratePlantTag.sql','CF6E83FB9F929F66DB0A43F394C366B94D3DE6B12EC0A8D227088B31228C5EB8','2026-05-06 18:12:32'),
(105,'202603191733_AlterPlant.sql','4F2FE76AE45F5AE46ECED5498AB96E384EE07CB743CDD4633DA0E7D86570D735','2026-05-06 18:12:32'),
(106,'202603191741_CreatePhoneticPrefix.sql','038018387B92750168B289E325CE04441AB33890CCC528F331683C06CEDE6D86','2026-05-06 18:12:32'),
(107,'202603191745_AddPrefix.sql','7F13F4B4CF27FB3FBEDA79357AA632F52F2F9FE1F9453626EDEDB00E85B00654','2026-05-06 18:12:32'),
(108,'202603191805_AddPlantTagAccession.sql','EB4407F391C7D7807E6BBD02705D189449B73131306DFBFA85EA5933BBF5124C','2026-05-06 18:12:32'),
(109,'202603192227_ConvertPlantTagGeneratorToFunction.sql','DDB5829D29D9CCFB21D8256FE10786CB5424EB87694AAC9A8A6F58C159BFF2E8','2026-05-06 18:12:32'),
(110,'202603192231_AddSpAddPlant.sql','13980ECF23C3ADA9B62F1BAB1300565C3FACB53573B15F874B5325FDB3190708','2026-05-06 18:12:32'),
(111,'202603201815_AlterSpSplitPlant.sql','14D6CD30D8ECB812A797F31968B820C1E2F8997EFB1852F636204C920A57AE6B','2026-05-06 18:12:32'),
(112,'202603210801_AlterSpSplitPlant.sql','75D265CF1FB0C2C361907D1841D033801F55003B74BD26A633944863DDFA2932','2026-05-06 18:12:32'),
(113,'202603211259_AlterSpSplitPlant.sql','5A199DB26CBCFDC60FFEDF349265540B8C0A145D49BE545E84811F024BC24D51','2026-05-06 18:12:32'),
(114,'202603221748_AddObservationType.sql','C79C6185A25D4CA417561281CD0AF49CB1B297A4A01D376220CB82F533C8D116','2026-05-06 18:12:32'),
(115,'202603231645_ApplyPlantStatusIndexes.sql','34562532D06C0D6B7B04D551525FC54A3F042399EFACA6DB855517CD99D58AA1','2026-05-06 18:12:32'),
(116,'202603231651_CreateVPlantStatus.sql','0ECB6817C53E4A0C2AFCC5CA668FCD2CFCDB4E619F45E222246DEF061AF881E2','2026-05-06 18:12:32'),
(117,'202603231812_AlterVPlantStatus.sql','1611905D412DEE57EBCBBEC66193DBEE543AFFFA33FE97F4581B6D96FF4422B5','2026-05-06 18:12:32'),
(118,'202603231955_AlterVPlantStatus.sql','D419F1F3B6A40B5CB6E36A5862672922E3CDB73EFF094745B25F3F6E973799E2','2026-05-06 18:12:32'),
(119,'202603240931_AlterVPlantStatus.sql','18229139751D1074200F3B2D487291BB36B27D99C7780671EBBF108B7A736B20','2026-05-06 18:12:32'),
(120,'202603241017_AlterVPlantSummary.sql','96F172DDB357DBE62E556401DEE4AD2E7914E247A820ED7696DB7812932F2443','2026-05-06 18:12:32'),
(121,'202603281435_AlterFlowering.sql','A145F78BF7DADFAEB764718D69EA625083893FCBFB3FFA42253182D125269599','2026-05-06 18:12:32'),
(122,'202603281437_AlterRepotting.sql','F55568EFCC7B4D77255D937178B9AE82244BDC25E199A61EA935E358D3E6476B','2026-05-06 18:12:32'),
(123,'202603281440_MigrateDateTimes.sql','4498358D9CAC99BFDB05F22B1800E6DB03D47EA5ABC9E22A172EB785B78FC106','2026-05-06 18:12:32'),
(124,'202603281442_AlterVPlantStatus.sql','D0A5F1F896DADC2F5797C58AAA0614D7C2F35367FF395B46507DD9DE728B8EA3','2026-05-06 18:12:32'),
(125,'202603281850_AlterSpUpdatePlantDetails.sql','EE5B4196297924469A7659BE7CC43916E9CF454E15B8C4F2BB3EADE086884C86','2026-05-06 18:12:32'),
(126,'202603281926_AlterSpAddPlant.sql','BC5B444378A95DE9D62D6CC127F74BDA267EBE2914F697FC08B88DFB500B4F91','2026-05-06 18:12:32'),
(127,'202603312042_AlterSpSplitPlant.sql','969C39B85FD284381CE5D5CE5B9BD813DD90AB0BE0FC6C9B4D65481B4748F2A3','2026-05-06 18:12:32'),
(128,'202604012206_AlterSpSplitPlant.sql','339CA7003EF69A190F98B7D6E3CCF08A79142402F4EE859AA546EF175F372082','2026-05-06 18:12:32'),
(129,'202604012215_AlterSpSplitPlant.sql','58432D9379AD401FE482D9A35A62A899C45C250D67C0AC494CFB86CA35636461','2026-05-06 18:12:32'),
(130,'202604021631_AlterSpSplitPlant.sql','72C0847C60B859DE28E114E924FC48556CCA76195A616081FDFE44C118F4792D','2026-05-06 18:12:32'),
(131,'202604021637_AlterSpSplitPlant.sql','A0CCF9AD89B0C54AA0043B2E42559564FBF4062AC093E363902EDBDD28D05714','2026-05-06 18:12:32'),
(132,'202604021648_AlterSpSplitPlant.sql','F905BB704E41F1C254F1AC5833759CBCBA2F044C955A02FACFBB8C0C6799C38C','2026-05-06 18:12:32'),
(133,'202604031028_AddMissingConstraints.sql','93B85162F3AC22E2938B5DF659BE67AB23C686585FED0238D5880AF1BBF7E6B2','2026-05-06 18:12:32'),
(134,'202604031550_AlterPlant.sql','9577CCF926C8F91BAD1B4EC766267C1BF459CD2EACA4CCD13690D711999B6809','2026-05-06 18:12:32'),
(135,'202604041125_CreateTaxonPhoto.sql','888BE802B263DC6A6C9AD0008B013E155C33970118BE22E3242166DB6FC1BA42','2026-05-06 18:12:32'),
(136,'202604051749_AlterSpUpdatePlantDetails.sql','C2A99C166FBE0887813F935A300E25E95C005D27B166BEF3C8AA72EB10F380DF','2026-05-06 18:12:32'),
(137,'202604061012_AlterPlantPhoto.sql','1EE524EBD5F6DEC10DB0F53AC4F5780E4D8A704C76FFC8070032B33ED436C6BB','2026-05-06 18:12:32'),
(138,'202604061016_AlterPlantPhoto.sql','B87043765D59EC943807B1DF96E4C56A74227681235C4ED8BE9C009D94DC775A','2026-05-06 18:12:32'),
(139,'202604092106_AlterVPlantStatus.sql','3266EDBDD5DCE5ADAF421694B9A1ECE73EE5848A4F59D47C8975F728E211A14B','2026-05-06 18:12:32'),
(140,'202604111439_AlterSpUpdatePlantDetails.sql','E12984FE717F6F1BD045B1AE9DB44A1521BC03C14AC8F0D29C044B1436CF2A88','2026-05-06 18:12:32'),
(141,'202604111824_AlterVPlantStatus.sql','FA77A3091669CDB10CE9E1316DD9745A54415E9E4CDDC6210873A49D4FEF7DAD','2026-05-06 18:12:32'),
(142,'202604111830_CreateVPlantSplitChildren.sql','7019CBC72E3469096420F4B5E3AA9C4B6E42D8B854A8CD9CAA7D5DB0675895C5','2026-05-06 18:12:32'),
(143,'202604120945_AlterVPlantStatus.sql','70957B71A15A7775B2F8A9E3FC6D1C7CB9C7089363AFD935C0AEBC4F23665AB0','2026-05-06 18:12:32'),
(144,'202604120951_AlterVLocationActiveList.sql','A00AB1F9063882EC6029386CED93AB4A5C746CA1991EF578B0C2088626E17C27','2026-05-06 18:12:32'),
(145,'202604121015_AlterVPlantSplitChildren.sql','9497C7B139AA7A366EF67FBAF495C3940F9A6F06FCF3FBF00546DD4E705E76C0','2026-05-06 18:12:32'),
(146,'202604121511_CreateVPlantCurrentGrowthMedium.sql','314B35EACEA3B093B341BD994C4CBCF895FFFA0C991D0347F85EA681EF9F4B35','2026-05-06 18:12:32'),
(147,'202604121518_AlterRepotting.sql','70D229040C54E9ACA20912BC40247C12E859EA1B1A8A743406D08763A5A532EC','2026-05-06 18:12:32'),
(148,'202604121546_AlterVPlantCurrentGrowthMedium.sql','690ED5957673FC975364D46B9E4BEC4B9BB5D8A753E19419E05988D9F39631CE','2026-05-06 18:12:32'),
(149,'202604121552_AlterVPlantCurrentGrowthMedium.sql','B89E89444FD825AE54FF8FB6BF7CD6F7A8EFE6DF7CD7D60573EB6511AE43054F','2026-05-06 18:12:32'),
(150,'202604122119_CreateSpGetPlantLineage.sql','3DC8EDC9E003D6711DE3FA289DFC13F39DD3DC4AA82E3B3849265CFA050A3BA3','2026-05-06 18:12:32'),
(151,'202604141818_AlterSpSplitPlant.sql','92FB356FD054600BB41046B20DF933E45D42B6A9800A888FABCC18B8E1A5F319','2026-05-06 18:12:32'),
(152,'202604142042_AlterSpUpdateGenus.sql','EA8B0FCD234C446ECE7B6273866C3EC81E3D7897CCC004EEC15103B35D6C5CF8','2026-05-06 18:12:32'),
(153,'202604162157_RenamePhoneticPrefix.sql','E44C141B5A12908D7EED97CC6E5BDBFF00ACB8D361363D947F542D7F7CCEE056','2026-05-06 18:12:32'),
(154,'202604162159_AlterFnGeneratePlantTag.sql','9071E2BD05270080D2BBDA00F60F0839A6EE4C12B92C8FB4745752DBB204AE9E','2026-05-06 18:12:32'),
(155,'202604181550_AlterVPlantActiveCurrentLocation.sql','B8D9DF36B28E083E1CF376C9E50D900AA3696509046D60FB8A89433867A2918F','2026-05-06 18:12:32'),
(156,'202604181603_AlterVPlantActiveCurrentLocation.sql','03AD061161D733E57D3CD1CB30959B87BFF6BC2A842E69DBC2B048FE0A843660','2026-05-06 18:12:32'),
(157,'202604181627_AlterPlantPhoto.sql','BF99875C6E2883BBB367363229A5C660FD0F39EB52A0E0AC6DDDE1E76882D543','2026-05-06 18:12:32'),
(158,'202604181632_AlterPlantPhoto.sql','E9FE73E2907735DC52C6CDF8F5E8AE2D8B23A87E8DA6F235B92FB37303CFCB68','2026-05-06 18:12:32'),
(159,'202604191657_AlterVPlantActiveCurrentLocation.sql','ECE4246CDB7FA4594ABAFC62A2500B6414E9382E1CFC793BA6AA5A60F33AACD9','2026-05-06 18:12:32'),
(160,'202604232214_CreateIndex.sql','BD3A8C21B33176F76E18A98479116A609011AE598C59ACFC8B8FFA48F722652B','2026-05-06 18:12:32'),
(161,'202604242021_AlterPlantEvent.sql','C57BD44B9F8B4980EF7B134B6D87DC7445B72ED398949611A12816AB8E6FCEBD','2026-05-06 18:12:32'),
(162,'202604252114_AlterTrgPlhSingleOpenBeforeInsert.sql','316DB868F46AEC9900C2FA7E274CC09B40FE354B790FDDC3E8C5E5EAD4E19980','2026-05-06 18:12:32'),
(163,'202604252120_AlterTrgPlhSingleOpenBeforeUpdate.sql','8763CED463FE19BC4FDFBBB958DC0F8D8E98CDCCBA9C6A4E62AFE75E325DE40E','2026-05-06 18:12:32'),
(164,'202604252126_AlterSpAddGenus.sql','2D425486DFE492D8288F01ABA28AAF32661CE4FDD7D29B71D87E4DDA2E8A2719','2026-05-06 18:12:32'),
(165,'202604252138_AlterSpUpdateGenus.sql','CE1DA8DB4EC89D8973BBCECFEA48707E75DC709AF7E2903FA6B328FC5FA3DB6A','2026-05-06 18:12:32'),
(166,'202604252155_AlterVPlantLifecycleHistory.sql','FFEC45C49A72476190082F62CE7A357AF186B3C28D02DA5FBEDE5096B023D063','2026-05-06 18:12:32'),
(167,'202604261448_AlterPlant.sql','E6DFF4C294DD28D2D7030CB16DB90A115D69961E71F6217363B314B3DFE6D0B0','2026-05-06 18:12:32'),
(168,'202604261449_AlterPlantEvent.sql','3BD194597AAA5EC252D47D7669D8536535FE077B6AF23929267721C6FE8D8E03','2026-05-06 18:12:32'),
(169,'202604261451_AlterPlantPhoto.sql','338E4D1328C1BC2FC42469F71EB9991CACB744B110B27B02354813BD0891447C','2026-05-06 18:12:32'),
(170,'202604261515_AlterPlantSplit.sql','5A9D2DD31A1BE4B8F6815D531E73B79D74993E052A33EBB098EDE04BFB28A0AC','2026-05-06 18:12:32'),
(171,'202604261517_AlterPlantSplitChild.sql','5C204F682695B9EF0CB22785BC11A9FC095A001AD060C3B7BCA98768C0423825','2026-05-06 18:12:32'),
(172,'202604261518_AlterRepotting.sql','DE8993CEBD23494DD0FD339A614644000F534339F0512EA1F81B1C07E792AD29','2026-05-06 18:12:32'),
(173,'202604261520_AlterTaxon.sql','E34AFADECF7674A06EEE95CFB928E08B43D973F42B845D9357DD350965EEBCC6','2026-05-06 18:12:32'),
(174,'202604261521_AlterTaxonPhoto.sql','6CA9C571A4FE2DD008CE893EC58A6351D730C5193E27A1919E09772F9702DCB3','2026-05-06 18:12:32'),
(175,'202604261523_AlterObservationType.sql','A06DAF35E707880D88103DC0CB78F945865A29BBF744CB44323BF4D80EA04EBE','2026-05-06 18:12:32'),
(176,'202604261540_RecreateSpGrowthMediumActiveState.sql','7FE05D981C73C393CE8D1447DD23738370AB32FB2D93A7CC1C72BFC084645E75','2026-05-06 18:12:32'),
(177,'202604261555_AlterDatabaseCollation.sql','A2978992F522F79D1966D41C5431AF482B5F3A8248F1925F1BB4FE9E026DA0C2','2026-05-06 18:12:32'),
(178,'202604261704_AlterSpUpdateGrowthMediumDetails.sql','64C6BEBCB2539232528D6EB4AD4CCD60ABD72A8680960555A892420A2A52CBF0','2026-05-06 18:12:32'),
(179,'202604261710_AlterSpUpdateLocationDetaills.sql','0195D28B002D5EC4CC1AF2A6F885A92640E57308A08FA9E11638027D9A57788F','2026-05-06 18:12:32'),
(180,'202604261714_AlterSpAddLocation.sql','2E151723CD1DAB94FF5518956F937D1AC2C7A7B8AB1C45107CF48946112CB8BC','2026-05-06 18:12:32'),
(181,'202604261718_AlterSpUpdateGenus.sql','15C9C08245DC6D2FA6285783331925FAC13547EF7AD05E484BB1DDF6A391BA89','2026-05-06 18:12:32'),
(182,'202604261720_AlterSpAddGenus.sql','6F7A69ABC7BCA6E1BB445CBE0E45CA73A139C7138057C7DCDE1B62D5A11ED3B1','2026-05-06 18:12:32'),
(183,'202604261725_AlterSpUpdateTaxonDetails.sql','94081F6068B4921FAC5F1F0F073CFB3E94FE9B94A540114C5202B76DE0B0A175','2026-05-06 18:12:32'),
(184,'202604261811_AlterSpUpdateTaxonDetails.sql','AEBE1C29D914C3702D808E191109DB4318E431F245A3DC61E6C27E493068421E','2026-05-06 18:12:32'),
(185,'202604261820_AlterSpAddPlant.sql','800DAAA0BC377CACFD29432A184FB6F5E8DB1497F34E30A9EB2FDC82DC44C349','2026-05-06 18:12:32'),
(186,'202604262108_AlterSpAddPlant.sql','800DAAA0BC377CACFD29432A184FB6F5E8DB1497F34E30A9EB2FDC82DC44C349','2026-05-06 18:12:32'),
(187,'202604262117_AlterFnGeneratePlantTag.sql','D729F24EA20CCA49D4C02C331E07BC24F180605C2B1385DCA73999B20A6ABAFC','2026-05-06 18:12:32'),
(188,'202604262207_AlterVPlantLifecycleHistory.sql','FFEC45C49A72476190082F62CE7A357AF186B3C28D02DA5FBEDE5096B023D063','2026-05-06 18:12:32'),
(189,'202604271422_AlterVPlantLifecycleHistory.sql','54038A00B35479170F7B996D11703CC9693DD39884C986D724970A566295FB0B','2026-05-06 18:12:32'),
(190,'202604271438_AlterVPlantLifecycleHistory.sql','4A4574BDFEDCA88B398457789D0982EDD1BC6EA6F3B1C2DF60059A97994A5F96','2026-05-06 18:12:32'),
(191,'202604271442_AlterVPlantLifecycleHistory.sql','4A4574BDFEDCA88B398457789D0982EDD1BC6EA6F3B1C2DF60059A97994A5F96','2026-05-06 18:12:32'),
(192,'202604271447_AlterVPlantLifecycleHistory.sql','A0A912BDBA74C7D0C3C38725760D6EE1C0A0EFBB051F4C4C9309B71528FE779C','2026-05-06 18:12:32'),
(193,'202604271507_AlterFnGeneratePlantTag.sql','42B207E4E628A05A9DC1FE8013B8E9541524D38722A39B41F1ACD9DDB90B5227','2026-05-06 18:12:32'),
(194,'202604271510_AlterSpAddGenus.sql','034084051F68925896DDEC3770E513B58DE74DDC9C334A60353A1646E1FAA38B','2026-05-06 18:12:32'),
(195,'202604271512_AlterSpAddLocation.sql','2E151723CD1DAB94FF5518956F937D1AC2C7A7B8AB1C45107CF48946112CB8BC','2026-05-06 18:12:32'),
(196,'202604271523_AlterSpAddTaxon.sql','F5685D240160D1EAF97FDE39A0906B02C594C1A06973AE00F61EB05FCCB9ED22','2026-05-06 18:12:32'),
(197,'202604271525_AlterSpAddTaxonInternal.sql','849B819902BD3D8CAE15B3D64B9F8729B1F36DE26D2F452018E3BAD435E272A9','2026-05-06 18:12:32'),
(198,'202604271526_AlterSpEditPlantLocation.sql','8180E1F72ABE001C87276832F5362C1B6688843F3A6DD37DEE04BFBE02445008','2026-05-06 18:12:32'),
(199,'202604271527_AlterSpGetPlantLineage.sql','27423F8EA11F6E3F5E8BACF22F5755706153BFEE3DE1A9435CF3B691626FD91C','2026-05-06 18:12:32'),
(200,'202604271529_AlterSpMovePlantToLocation.sql','445F18BEE56F43A40116FCA8F9FBB964C426B30528BC5A88A70AF5F938B83BD3','2026-05-06 18:12:32'),
(201,'202604271532_AlterSpRemovePlantLocation.sql','01007C009A4253541BDD2E275F5A17A78ED57C1364DFF11D40FFC6679FBAEB0C','2026-05-06 18:12:32'),
(202,'202604271535_AlterSpSetGenusActiveState.sql','119E188862732B34459BC678C25A1D72F4EC8E0EFEFCFF3A940A5C5AA11ADAEA','2026-05-06 18:12:32'),
(203,'202604271542_AlterSpSetGrowthMediumActiveState.sql','13A3C78B3B90DAEC7DE3FBC6DABF7B4FF46466089D3538EA323592B292B5CA53','2026-05-06 18:12:32'),
(204,'202604271543_AlterSpSetHeroPhoto.sql','AAF8DCC597F4F513B991E7831DA95EF8844A085D177DD0D0B16296851AF2B885','2026-05-06 18:12:32'),
(205,'202604271547_AlterSpSetLocationActiveState.sql','F63165F1193F6104257D8261619EF7C944EABA7C66A9EDFF48C8356F63A4FBDB','2026-05-06 18:12:32'),
(206,'202604271548_AlterSpSetTaxonActiveState.sql','F59D055156BB40F89F6745F77A2F0A6106F15D199305F937F7945DD43732D547','2026-05-06 18:12:32'),
(207,'202604271550_AlterSpSplitPlant.sql','E0D10311ADA62A8B10FE2C4E210D2253EC1FC25604BAD8968FD6B812844515E0','2026-05-06 18:12:32'),
(208,'202604271551_AlterSpUpdateGenus.sql','15C9C08245DC6D2FA6285783331925FAC13547EF7AD05E484BB1DDF6A391BA89','2026-05-06 18:12:32'),
(209,'202604271553_AlterSpUpdateGenus.sql','15C9C08245DC6D2FA6285783331925FAC13547EF7AD05E484BB1DDF6A391BA89','2026-05-06 18:12:32'),
(210,'202604271556_AlterSpUpdateGrowthMediumDetails.sql','41DF6EA89873DE00AC0E88FC3B4321D38CF3FB23384A0E00A509C5208271D88C','2026-05-06 18:12:32'),
(211,'202604271602_AlterSpUpdateLocationDetails.sql','0195D28B002D5EC4CC1AF2A6F885A92640E57308A08FA9E11638027D9A57788F','2026-05-06 18:12:32'),
(212,'202604271604_AlterSpUpdatePlantDetails.sql','E19F65641D46FC713DD5EA4F7AD9CD004A636DA796E0E8CE29716C161B0B8847','2026-05-06 18:12:32'),
(213,'202604271605_AlterSpUpdateTaxonDetails.sql','8B90D025B5D382604E7E18761DD0D21D562E7F98EE2AD963FDBA99DF005972FC','2026-05-06 18:12:32'),
(214,'202604272212_CreateTrgPlantLocationHistoryBeforeInsert.sql','DABB7EF375085C80F18C43ADC7E7CF4D0967ACF4333BAC84BA0685E5C9C997A3','2026-05-06 18:12:32'),
(215,'202604272217_CreateTrgPlantLocationHistoryBeforeUpdate.sql','4D430250B7205E221B5720EA17E78D4AFC8FEC48F3A3051AD9B3FECE97770ABD','2026-05-06 18:12:32'),
(216,'202604281449_AlterSpEditPlantLocation.sql','3ABEF5FBBC17360AE79A2A3945BC8C4D50DF37C0FEA3E4A1836C017F34CDD2F7','2026-05-06 18:12:32'),
(217,'202604281602_AlterPlantSplitChild.sql','93EBC6FC4C0103A47C6A7DD5DE2EFFBC9F73AABCBEBF6841308764295E6E40AD','2026-05-06 18:12:32'),
(218,'202604281603_CreatePlantPropagation.sql','2EBED10F20D74586D22D98DB5E1C4FD6AA2AE42A3804E27A66C35EDAB762D22E','2026-05-06 18:12:32'),
(219,'202604281613_CreatePropagationType.sql','6F1F0A7053DC05EC43E3FAC8F18B4F74DD5C0DBAB4305507B67933BF7F3B38E3','2026-05-06 18:12:32'),
(220,'202604281615_CreatePlantPropagation.sql','2EBED10F20D74586D22D98DB5E1C4FD6AA2AE42A3804E27A66C35EDAB762D22E','2026-05-06 18:12:32'),
(221,'202604281627_CreateSpPropagatePlant.sql','991A82097B5357CC0DA909DCDD0CEB72CCE684F0AA82013A398C2840096468D2','2026-05-06 18:12:32'),
(222,'202604281635_AlterSpPropagatePlant.sql','A2DD4A24001CF46519FCD6E43DEBD0F8E5C1F870F6D41473F84BF5DA25218DF7','2026-05-06 18:12:32'),
(223,'202604281913_AlterSpSplitPlant.sql','378ED8213254E07A174BE057FF252C058C14E49DBA5C8E1E5A4371A804158AB1','2026-05-06 18:12:32'),
(224,'202604281920_AlterSpPropagatePlant.sql','DCB22D8AADEFECE262EED7814EA8073A82E9C0455348773C7E951FADF46B28B7','2026-05-06 18:12:32'),
(225,'202604291749_CreateVPlantLineage.sql','CEF72D95D0B68283D3D0B5980AF20F722FE819F708C74308FB5AA89470D86DFF','2026-05-06 18:12:32'),
(226,'202604291757_AlterVPlantStatus.sql','2B8454E124965C656055CF7E5E8A32D6F2CBA18693F1BBB14DF37EF40D17E325','2026-05-06 18:12:32'),
(227,'202604291812_AlterVPlantLineage.sql','2797378857C450868FF5023B9AA27F1FB35643196FB817C5EEEE197274036937','2026-05-06 18:12:32'),
(228,'202604292032_AlterVPlantStatus.sql','4979CD74ED6AF1D4153DF6FDEA6F614EF84055331FCFA06FFC8E766CDC2B6B57','2026-05-06 18:12:32'),
(229,'202604302002_CreatevPlantRepotStatus.sql','4C143C0299DF63EBB9D910B308C32084885C516991E7F76138D36C8D5D1CC487','2026-05-06 18:12:32'),
(230,'202604302009_AlterVPlantRepotStatus.sql','A47B39AE90425052F4986316361DDF1B8B0AA8EC9F2113263FC7983BCCF12B8D','2026-05-06 18:12:32'),
(231,'202604302035_AlterVPlantRepotStatus.sql','738BA0074187268300E7A3AE516DCB8ED204E943EEA4265927075078940EEC2B','2026-05-06 18:12:32'),
(232,'202604302038_AlterVPlantRepotStatus.sql','2E0748684233A20F1A8C809105CD3CC13E2364EDA0C9B402BEF4D98A7215B83B','2026-05-06 18:12:32'),
(233,'202605011527_CreateVPlantCurrentlyFlowering.sql','D8F94F6CE251D096384D2EDD56E6B2957BF738EB3BCD4A110E292382969FF812','2026-05-06 18:12:32'),
(234,'202605011530_CreateVPlantsSinceLastFlowered.sql','A9B8ADA8D7FF5B824C2F5B45256A6EB1CB85FBA8716F31B6394AEF6D43A4E6D8','2026-05-06 18:12:32');
/*!40000 ALTER TABLE `schemaversion` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `taxon`
--

DROP TABLE IF EXISTS `taxon`;
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
  KEY `fkTaxonGenus` (`genusId`),
  CONSTRAINT `fkTaxonGenus` FOREIGN KEY (`genusId`) REFERENCES `genus` (`genusId`),
  CONSTRAINT `chkTaxon_Shape` CHECK (`speciesName` is null and `hybridName` is null or `speciesName` is not null and `hybridName` is null or `speciesName` is null and `hybridName` is not null),
  CONSTRAINT `chkTaxonIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Taxonomic information for orchid species and hybrids.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxon`
--

LOCK TABLES `taxon` WRITE;
/*!40000 ALTER TABLE `taxon` DISABLE KEYS */;
/*!40000 ALTER TABLE `taxon` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `taxonphoto`
--

DROP TABLE IF EXISTS `taxonphoto`;
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
  KEY `fkTaxonPhotoTaxon` (`taxonId`),
  CONSTRAINT `fkTaxonPhotoTaxon` FOREIGN KEY (`taxonId`) REFERENCES `taxon` (`taxonId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxonphoto`
--

LOCK TABLES `taxonphoto` WRITE;
/*!40000 ALTER TABLE `taxonphoto` DISABLE KEYS */;
/*!40000 ALTER TABLE `taxonphoto` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Temporary table structure for view `vlocationactivelist`
--

DROP TABLE IF EXISTS `vlocationactivelist`;
/*!50001 DROP VIEW IF EXISTS `vlocationactivelist`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vlocationactivelist` AS SELECT
 1 AS `locationId`,
  1 AS `locationName`,
  1 AS `locationTypeCode`,
  1 AS `climateCode` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantactivecurrentlocation`
--

DROP TABLE IF EXISTS `vplantactivecurrentlocation`;
/*!50001 DROP VIEW IF EXISTS `vplantactivecurrentlocation`*/;
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

--
-- Temporary table structure for view `vplantactivesummary`
--

DROP TABLE IF EXISTS `vplantactivesummary`;
/*!50001 DROP VIEW IF EXISTS `vplantactivesummary`*/;
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

--
-- Temporary table structure for view `vplantcurrentgrowthmedium`
--

DROP TABLE IF EXISTS `vplantcurrentgrowthmedium`;
/*!50001 DROP VIEW IF EXISTS `vplantcurrentgrowthmedium`*/;
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

--
-- Temporary table structure for view `vplantcurrentlocation`
--

DROP TABLE IF EXISTS `vplantcurrentlocation`;
/*!50001 DROP VIEW IF EXISTS `vplantcurrentlocation`*/;
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

--
-- Temporary table structure for view `vplantcurrentlyflowering`
--

DROP TABLE IF EXISTS `vplantcurrentlyflowering`;
/*!50001 DROP VIEW IF EXISTS `vplantcurrentlyflowering`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantcurrentlyflowering` AS SELECT
 1 AS `plantId`,
  1 AS `plantTag`,
  1 AS `locationName`,
  1 AS `genusId`,
  1 AS `genusName`,
  1 AS `displayName`,
  1 AS `floweringStartDate` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantlifecyclehistory`
--

DROP TABLE IF EXISTS `vplantlifecyclehistory`;
/*!50001 DROP VIEW IF EXISTS `vplantlifecyclehistory`*/;
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

--
-- Temporary table structure for view `vplantlineage`
--

DROP TABLE IF EXISTS `vplantlineage`;
/*!50001 DROP VIEW IF EXISTS `vplantlineage`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantlineage` AS SELECT
 1 AS `childPlantId`,
  1 AS `parentPlantId`,
  1 AS `relationshipType` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantrepotstatus`
--

DROP TABLE IF EXISTS `vplantrepotstatus`;
/*!50001 DROP VIEW IF EXISTS `vplantrepotstatus`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantrepotstatus` AS SELECT
 1 AS `plantId`,
  1 AS `plantTag`,
  1 AS `locationName`,
  1 AS `genusId`,
  1 AS `genusName`,
  1 AS `displayName`,
  1 AS `acquisitionDate`,
  1 AS `lastRepotDate`,
  1 AS `effectiveRepotDate`,
  1 AS `monthsSinceRepot`,
  1 AS `repotStatus`,
  1 AS `repotSummary` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantsincelastflowered`
--

DROP TABLE IF EXISTS `vplantsincelastflowered`;
/*!50001 DROP VIEW IF EXISTS `vplantsincelastflowered`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantsincelastflowered` AS SELECT
 1 AS `plantId`,
  1 AS `plantTag`,
  1 AS `acquisitionDate`,
  1 AS `locationName`,
  1 AS `genusId`,
  1 AS `genusName`,
  1 AS `displayName`,
  1 AS `lastFlowerEndDate`,
  1 AS `monthsSinceFlower` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantsplitchildren`
--

DROP TABLE IF EXISTS `vplantsplitchildren`;
/*!50001 DROP VIEW IF EXISTS `vplantsplitchildren`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `vplantsplitchildren` AS SELECT
 1 AS `parentPlantId`,
  1 AS `childPlantId`,
  1 AS `plantTag`,
  1 AS `acquisitionDate` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vplantstatus`
--

DROP TABLE IF EXISTS `vplantstatus`;
/*!50001 DROP VIEW IF EXISTS `vplantstatus`*/;
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
  1 AS `parentRelationshipType`,
  1 AS `hasChildren` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `vtaxonidentity`
--

DROP TABLE IF EXISTS `vtaxonidentity`;
/*!50001 DROP VIEW IF EXISTS `vtaxonidentity`*/;
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

--
-- Dumping events for database 'orchids'
--

--
-- Dumping routines for database 'orchids'
--
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fnGeneratePlantTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` FUNCTION `fnGeneratePlantTag`() RETURNS char(8) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci
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
/*!50003 DROP PROCEDURE IF EXISTS `spAddGenus` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spAddGenus`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spAddLocation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spAddLocation`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spAddPlant` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spAddPlant`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spAddTaxon` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spAddTaxon`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spAddTaxonInternal` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spAddTaxonInternal`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spEditPlantLocation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spEditPlantLocation`(
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
            moveReasonNotes    = NULLIF(pMoveReasonNotes, ''),
            plantLocationNotes = NULLIF(pPlantLocationNotes, '')
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
/*!50003 DROP PROCEDURE IF EXISTS `spGetPlantLineage` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spGetPlantLineage`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spMovePlantToLocation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spMovePlantToLocation`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spPropagatePlant` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spPropagatePlant`(

    IN pParentPlantId INT,
    IN pPropagationDate DATE,
    IN pPropagationTypeId INT,
    IN pChildPlantName VARCHAR(100),
    IN pMediumId INT,
    IN pPropagationNotes TEXT

)
BEGIN

    DECLARE vTaxonId INT;
    DECLARE vParentPlantTag CHAR(8);
    DECLARE vParentStart DATETIME;
    DECLARE vParentEnd DATETIME;
    DECLARE vTaxonIsActive TINYINT;
    DECLARE vGenusIsActive TINYINT;

    DECLARE vChildTag CHAR(8);
    DECLARE vChildPlantId INT;

    DECLARE vPropagationDateTime DATETIME;
    DECLARE vPropagationTypeName VARCHAR(100);

    IF pParentPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant id is required';
    END IF;

    IF pPropagationDate IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date is required';
    END IF;

    IF pPropagationTypeId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation type is required';
    END IF;

    IF pPropagationDate > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date cannot be in the future';
    END IF;

    SET vPropagationDateTime = TIMESTAMP(
        pPropagationDate,
        TIME(NOW())
    );

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

    IF vPropagationDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation datetime cannot be before plant lifecycle start';
    END IF;

    SELECT propagationTypeName
    INTO vPropagationTypeName
    FROM propagationtype
    WHERE propagationTypeId = pPropagationTypeId
    AND isActive = 1;

    IF vPropagationTypeName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid propagation type';
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
        pChildPlantName,
        vPropagationDateTime,
        CONCAT(vPropagationTypeName, ' from ', vParentPlantTag),
        1
    );

    SET vChildPlantId = LAST_INSERT_ID();

    IF EXISTS (
        SELECT 1
        FROM plantsplitchild
        WHERE childPlantId = vChildPlantId
        AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant already has a split origin';
    END IF;

    IF pMediumId IS NOT NULL THEN
        INSERT INTO repotting (
            plantId,
            repotDate,
            newGrowthMediumId,
            repotReasonNotes,
            isActive
        )
        VALUES (
            vChildPlantId,
            vPropagationDateTime,
            pMediumId,
            'Initial medium from propagation',
            1
        );
    END IF;

    INSERT INTO plantpropagation (
        parentPlantId,
        childPlantId,
        propagationTypeId,
        propagationDateTime,
        propagationNotes,
        isActive
    )
    VALUES (
        pParentPlantId,
        vChildPlantId,
        pPropagationTypeId,
        vPropagationDateTime,
        pPropagationNotes,
        1
    );

    SELECT
        vChildPlantId AS childPlantId,
        vChildTag AS childPlantTag;

    COMMIT;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `spRemovePlantLocation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spRemovePlantLocation`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spSetGenusActiveState` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSetGenusActiveState`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spSetGrowthMediumActiveState` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSetGrowthMediumActiveState`(
    IN pGrowthMediumId INT,
    IN pIsActive BOOLEAN
)
proc: BEGIN

    DECLARE vCurrentState BOOLEAN;

    SELECT isActive
    INTO vCurrentState
    FROM growthmedium
    WHERE growthMediumId = pGrowthMediumId;

    IF vCurrentState = pIsActive THEN
        LEAVE proc;
    END IF;

    UPDATE growthmedium
    SET isActive = pIsActive
    WHERE growthMediumId = pGrowthMediumId;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `spSetHeroPhoto` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSetHeroPhoto`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spSetLocationActiveState` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSetLocationActiveState`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spSetTaxonActiveState` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSetTaxonActiveState`(
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
/*!50003 DROP PROCEDURE IF EXISTS `spSplitPlant` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spSplitPlant`(

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

        IF EXISTS (
            SELECT 1
            FROM plantpropagation
            WHERE childPlantId = vChildPlantId
            AND isActive = 1
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Plant already has a propagation origin';
        END IF;

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
/*!50003 DROP PROCEDURE IF EXISTS `spUpdateGenus` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spUpdateGenus`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spUpdateGrowthMediumDetails` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spUpdateGrowthMediumDetails`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spUpdateLocationDetails` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spUpdateLocationDetails`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spUpdatePlantDetails` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spUpdatePlantDetails`(

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
/*!50003 DROP PROCEDURE IF EXISTS `spUpdateTaxonDetails` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`orchid`@`localhost` PROCEDURE `spUpdateTaxonDetails`(

    IN p_taxonId INT,

    IN p_speciesName VARCHAR(100),

    IN p_hybridName VARCHAR(150),

    IN p_growthCode VARCHAR(30),

    IN p_growthNotes TEXT,

    IN p_taxonNotes TEXT

)
BEGIN

    DECLARE v_genusId INT;

    DECLARE v_isSystemManaged TINYINT;

    DECLARE v_existingSpecies VARCHAR(100);

    DECLARE v_existingHybrid VARCHAR(150);

    SET p_speciesName = NULLIF(TRIM(p_speciesName), '');

    SET p_hybridName  = NULLIF(TRIM(p_hybridName), '');

    SELECT isSystemManaged, speciesName, hybridName, genusId

    INTO v_isSystemManaged, v_existingSpecies, v_existingHybrid, v_genusId

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

            WHERE genusId = v_genusId

              AND speciesName = p_speciesName

              AND taxonId <> p_taxonId

        ) THEN

            SIGNAL SQLSTATE '45000'

            SET MESSAGE_TEXT = 'Species already exists';

        END IF;

        IF p_hybridName IS NOT NULL AND EXISTS (

            SELECT 1

            FROM taxon

            WHERE genusId = v_genusId

              AND hybridName = p_hybridName

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

--
-- Current Database: `orchids`
--

USE `orchids`;

--
-- Final view structure for view `vlocationactivelist`
--

/*!50001 DROP VIEW IF EXISTS `vlocationactivelist`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vlocationactivelist` AS select `location`.`locationId` AS `locationId`,`location`.`locationName` AS `locationName`,`location`.`locationTypeCode` AS `locationTypeCode`,`location`.`climateCode` AS `climateCode` from `location` where `location`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantactivecurrentlocation`
--

/*!50001 DROP VIEW IF EXISTS `vplantactivecurrentlocation`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantactivecurrentlocation` AS select `p`.`plantId` AS `plantId`,`t`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`t`.`isActive` AS `taxonIsActive`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end AS `displayName`,`pp`.`fileName` AS `heroFileName`,`pp`.`thumbnailFileName` AS `heroThumbnailFileName` from (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (select `sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime` from (select `lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc) AS `RowOrder` from `plantlocationhistory` `lochistory` where `lochistory`.`isActive` = 1) `sub` where `sub`.`RowOrder` = 1) `plh` on(`p`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) left join `plantphoto` `pp` on(`pp`.`plantId` = `p`.`plantId` and `pp`.`isHero` = 1 and `pp`.`isActive` = 1)) where `p`.`isActive` = 1 and `p`.`endDate` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantactivesummary`
--

/*!50001 DROP VIEW IF EXISTS `vplantactivesummary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantactivesummary` AS select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`s`.`isActive` AS `taxonIsActive`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,case when `s`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `s`.`speciesName` is not null then concat(`g`.`genusName`,' ',`s`.`speciesName`) when `s`.`hybridName` is not null then concat(`g`.`genusName`,' ',`s`.`hybridName`) else `g`.`genusName` end AS `displayName` from ((`plant` `p` join `taxon` `s` on(`s`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `s`.`genusId`)) where `p`.`isActive` = 1 and `p`.`endDate` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantcurrentgrowthmedium`
--

/*!50001 DROP VIEW IF EXISTS `vplantcurrentgrowthmedium`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantcurrentgrowthmedium` AS select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `repotting`.`repottingId` AS `repottingId`,`repotting`.`plantId` AS `plantId`,`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`repotting`.`potSize` AS `potSize`,`repotting`.`repottingNotes` AS `repottingNotes`,`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `repotting`.`plantId` order by `repotting`.`repotDate` desc,`repotting`.`repottingId` desc) AS `rn` from `repotting` where `repotting`.`isActive` = 1) `r` join `growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantcurrentlocation`
--

/*!50001 DROP VIEW IF EXISTS `vplantcurrentlocation`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantcurrentlocation` AS select `plh`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`plant`.`plantId` AS `plantId`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,`plant`.`plantTag` AS `plantTag`,`plant`.`plantName` AS `plantName`,`taxon`.`taxonId` AS `taxonId`,`genus`.`genusName` AS `genusName`,`genus`.`isActive` AS `genusIsActive`,case when `taxon`.`isSystemManaged` = 1 then concat(`genus`.`genusName`,' sp.') when `taxon`.`speciesName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`speciesName`) when `taxon`.`hybridName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`hybridName`) else `genus`.`genusName` end AS `displayName`,`plant`.`endDate` AS `plantEndDate`,`plh`.`RowOrder` AS `RowOrder` from ((((`plant` join `taxon` on(`taxon`.`taxonId` = `plant`.`taxonId`)) join `genus` on(`genus`.`genusId` = `taxon`.`genusId`)) left join (select `sub`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`endDateTime` AS `endDateTime`,`sub`.`moveReasonCode` AS `moveReasonCode`,`sub`.`moveReasonNotes` AS `moveReasonNotes`,`sub`.`plantLocationNotes` AS `plantLocationNotes`,`sub`.`createdDateTime` AS `createdDateTime`,`sub`.`isActive` AS `isActive`,`sub`.`updatedDateTime` AS `updatedDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,`lochistory`.`endDateTime` AS `endDateTime`,`lochistory`.`moveReasonCode` AS `moveReasonCode`,`lochistory`.`moveReasonNotes` AS `moveReasonNotes`,`lochistory`.`plantLocationNotes` AS `plantLocationNotes`,`lochistory`.`createdDateTime` AS `createdDateTime`,`lochistory`.`isActive` AS `isActive`,`lochistory`.`updatedDateTime` AS `updatedDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc) AS `RowOrder` from `plantlocationhistory` `lochistory` where `lochistory`.`isActive` = 1) `sub` where `sub`.`RowOrder` = 1) `plh` on(`plant`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) where `plant`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantcurrentlyflowering`
--

/*!50001 DROP VIEW IF EXISTS `vplantcurrentlyflowering`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantcurrentlyflowering` AS select `p`.`plantId` AS `plantId`,`p`.`plantTag` AS `plantTag`,`l`.`locationName` AS `locationName`,`g`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end AS `displayName`,`f`.`startDate` AS `floweringStartDate` from (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) join `flowering` `f` on(`f`.`plantId` = `p`.`plantId` and `f`.`isActive` = 1 and `f`.`endDate` is null)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) where `p`.`endDate` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantlifecyclehistory`
--

/*!50001 DROP VIEW IF EXISTS `vplantlifecyclehistory`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantlifecyclehistory` AS with plant_identity as (select `p`.`plantId` AS `plantId` from `plant` `p` where `p`.`isActive` = 1)select `pi`.`plantId` AS `plantId`,`pe`.`eventDateTime` AS `eventDateTime`,'Observation' collate utf8mb4_unicode_ci AS `eventType`,`pe`.`eventDetails` collate utf8mb4_unicode_ci AS `eventSummary`,'plantevent' collate utf8mb4_unicode_ci AS `sourceTable`,`pe`.`plantEventId` AS `sourceId` from (`plant_identity` `pi` join `plantevent` `pe` on(`pe`.`plantId` = `pi`.`plantId`)) where `pe`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,cast(`r`.`repotDate` as datetime) AS `eventDateTime`,'Repotting' collate utf8mb4_unicode_ci AS `eventType`,concat('Repotted',case when `r`.`oldGrowthMediumId` is not null and `r`.`newGrowthMediumId` is not null then concat(' FROM ',`oldgm`.`name`,' to ',`newgm`.`name`) when `r`.`oldGrowthMediumId` is not null then concat(' FROM ',`oldgm`.`name`) when `r`.`newGrowthMediumId` is not null then concat(' into ',`newgm`.`name`) else '' end,case when coalesce(nullif(`r`.`repottingNotes`,''),nullif(`r`.`repotReasonNotes`,''),nullif(`r`.`newMediumNotes`,''),nullif(`r`.`oldMediumNotes`,'')) is not null then concat(' - ',coalesce(nullif(`r`.`repottingNotes`,''),nullif(`r`.`repotReasonNotes`,''),nullif(`r`.`newMediumNotes`,''),nullif(`r`.`oldMediumNotes`,''))) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'repotting' collate utf8mb4_unicode_ci AS `sourceTable`,`r`.`repottingId` AS `sourceId` from (((`plant_identity` `pi` join `repotting` `r` on(`r`.`plantId` = `pi`.`plantId`)) left join `growthmedium` `oldgm` on(`r`.`oldGrowthMediumId` = `oldgm`.`growthMediumId`)) left join `growthmedium` `newgm` on(`r`.`newGrowthMediumId` = `newgm`.`growthMediumId`)) where `r`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,cast(`f`.`startDate` as datetime) AS `eventDateTime`,'Flowering' collate utf8mb4_unicode_ci AS `eventType`,concat('Flowered',case when `f`.`startDate` is not null and `f`.`endDate` is not null then concat(' FROM ',date_format(`f`.`startDate`,'%d-%m-%Y'),' to ',date_format(`f`.`endDate`,'%d-%m-%Y')) when `f`.`startDate` is not null and `f`.`endDate` is null then concat(' FROM ',date_format(`f`.`startDate`,'%d-%m-%Y'),' (currently flowering)') else '' end,case when `f`.`flowerCount` is not null and `f`.`spikeCount` is not null then concat(' with ',if(`f`.`flowerCount` = 1,'1 flower',concat(`f`.`flowerCount`,' flowers')),' over ',if(`f`.`spikeCount` = 1,'1 spike',concat(`f`.`spikeCount`,' spikes'))) when `f`.`flowerCount` is not null then concat(' with ',if(`f`.`flowerCount` = 1,'1 flower',concat(`f`.`flowerCount`,' flowers'))) when `f`.`spikeCount` is not null then concat(' over ',if(`f`.`spikeCount` = 1,'1 spike',concat(`f`.`spikeCount`,' spikes'))) else '' end,case when `f`.`floweringNotes` is not null and `f`.`floweringNotes` <> '' then concat(' - ',`f`.`floweringNotes`) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'flowering' collate utf8mb4_unicode_ci AS `sourceTable`,`f`.`floweringId` AS `sourceId` from (`plant_identity` `pi` join `flowering` `f` on(`f`.`plantId` = `pi`.`plantId`)) where `f`.`isActive` = 1 union all select `pi`.`plantId` AS `plantId`,`plh`.`startDateTime` AS `eventDateTime`,'LocationChange' collate utf8mb4_unicode_ci AS `eventType`,concat('Moved to ',`l`.`locationName`,' on ',date_format(`plh`.`startDateTime`,'%d-%m-%Y'),case when `plh`.`endDateTime` is not null then concat(' to ',date_format(`plh`.`endDateTime`,'%d-%m-%Y')) else ' (current)' end,case when `plh`.`moveReasonNotes` is not null and `plh`.`moveReasonNotes` <> '' then concat(' : ',`plh`.`moveReasonNotes`) else '' end,case when `plh`.`plantLocationNotes` is not null and `plh`.`plantLocationNotes` <> '' then concat(' - ',`plh`.`plantLocationNotes`) else '' end) collate utf8mb4_unicode_ci AS `eventSummary`,'plantlocationhistory' collate utf8mb4_unicode_ci AS `sourceTable`,`plh`.`plantLocationHistoryId` AS `sourceId` from ((`plant_identity` `pi` join `plantlocationhistory` `plh` on(`plh`.`plantId` = `pi`.`plantId`)) join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) where `plh`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantlineage`
--

/*!50001 DROP VIEW IF EXISTS `vplantlineage`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantlineage` AS select `c`.`childPlantId` AS `childPlantId`,`s`.`parentPlantId` AS `parentPlantId`,'Split' AS `relationshipType` from (`plantsplitchild` `c` join `plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) where `c`.`isActive` = 1 union all select `p`.`childPlantId` AS `childPlantId`,`p`.`parentPlantId` AS `parentPlantId`,`pt`.`propagationTypeName` AS `relationshipType` from (`plantpropagation` `p` join `propagationtype` `pt` on(`pt`.`propagationTypeId` = `p`.`propagationTypeId`)) where `p`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantrepotstatus`
--

/*!50001 DROP VIEW IF EXISTS `vplantrepotstatus`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantrepotstatus` AS select `base`.`plantId` AS `plantId`,`base`.`plantTag` AS `plantTag`,`base`.`locationName` AS `locationName`,`base`.`genusId` AS `genusId`,`base`.`genusName` AS `genusName`,`base`.`displayName` AS `displayName`,`base`.`acquisitionDate` AS `acquisitionDate`,`base`.`lastRepotDate` AS `lastRepotDate`,coalesce(`base`.`lastRepotDate`,`base`.`acquisitionDate`) AS `effectiveRepotDate`,`base`.`monthsSinceRepot` AS `monthsSinceRepot`,case when `base`.`lastRepotDate` is null and `base`.`acquisitionDate` is null then 'Unknown' when `base`.`lastRepotDate` is not null then 'Repotted' else 'FROM acquisition' end AS `repotStatus`,case when `base`.`lastRepotDate` is null and `base`.`acquisitionDate` is null then 'No repotting information' else concat(`base`.`monthsSinceRepot`,case when `base`.`monthsSinceRepot` = 1 then ' month since ' else ' months since ' end,case when `base`.`lastRepotDate` is not null then 'repot' else 'acquisition' end,' (',date_format(`base`.`effectiveDate`,'%d/%m/%Y'),')') end AS `repotSummary` from (select `p`.`plantId` AS `plantId`,`p`.`plantTag` AS `plantTag`,`l`.`locationName` AS `locationName`,`g`.`genusName` AS `genusName`,`g`.`genusId` AS `genusId`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end AS `displayName`,`p`.`acquisitionDate` AS `acquisitionDate`,`repot`.`lastRepotDate` AS `lastRepotDate`,coalesce(`repot`.`lastRepotDate`,`p`.`acquisitionDate`) AS `effectiveDate`,timestampdiff(MONTH,coalesce(`repot`.`lastRepotDate`,`p`.`acquisitionDate`),curdate()) AS `monthsSinceRepot` from (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (select `r`.`plantId` AS `plantId`,max(`r`.`repotDate`) AS `lastRepotDate` from `repotting` `r` where `r`.`isActive` = 1 group by `r`.`plantId`) `repot` on(`repot`.`plantId` = `p`.`plantId`)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) where `p`.`endDate` is null) `base` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantsincelastflowered`
--

/*!50001 DROP VIEW IF EXISTS `vplantsincelastflowered`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantsincelastflowered` AS select `p`.`plantId` AS `plantId`,`p`.`plantTag` AS `plantTag`,`p`.`acquisitionDate` AS `acquisitionDate`,`l`.`locationName` AS `locationName`,`g`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end AS `displayName`,`lastflower`.`lastFlowerEndDate` AS `lastFlowerEndDate`,timestampdiff(MONTH,`lastflower`.`lastFlowerEndDate`,curdate()) AS `monthsSinceFlower` from (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (select `f`.`plantId` AS `plantId`,max(`f`.`endDate`) AS `lastFlowerEndDate` from `flowering` `f` where `f`.`isActive` = 1 and `f`.`endDate` is not null group by `f`.`plantId`) `lastflower` on(`lastflower`.`plantId` = `p`.`plantId`)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) where `p`.`endDate` is null and !exists(select 1 from `flowering` `f2` where `f2`.`plantId` = `p`.`plantId` and `f2`.`isActive` = 1 and `f2`.`endDate` is null limit 1) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantsplitchildren`
--

/*!50001 DROP VIEW IF EXISTS `vplantsplitchildren`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantsplitchildren` AS select `ps`.`parentPlantId` AS `parentPlantId`,`child`.`plantId` AS `childPlantId`,`child`.`plantTag` AS `plantTag`,`child`.`acquisitionDate` AS `acquisitionDate` from ((`plantsplit` `ps` join `plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vplantstatus`
--

/*!50001 DROP VIEW IF EXISTS `vplantstatus`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vplantstatus` AS select `p`.`plantId` AS `plantId`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`p`.`endDate` AS `endDate`,`p`.`plantTag` AS `plantTag`,trim(case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end) AS `displayName`,`t`.`isActive` AS `taxonIsActive`,`g`.`isActive` AS `genusIsActive`,`l`.`locationName` AS `locationName`,`lf`.`startDate` AS `lastFloweringDate`,`lr`.`repotDate` AS `lastRepotDate`,`gm`.`name` AS `currentGrowthMediumName`,`lfeed`.`eventDateTime` AS `lastFeedDateTime`,`ot`.`displayName` AS `lastFeedTypeDisplayName`,case when exists(select 1 from `vplantlineage` `lp` where `lp`.`childPlantId` = `p`.`plantId` limit 1) then 1 else 0 end AS `hasParent`,(select `lp`.`parentPlantId` from `vplantlineage` `lp` where `lp`.`childPlantId` = `p`.`plantId` limit 1) AS `parentPlantId`,(select `parent`.`plantTag` from (`vplantlineage` `lp` join `plant` `parent` on(`parent`.`plantId` = `lp`.`parentPlantId`)) where `lp`.`childPlantId` = `p`.`plantId` limit 1) AS `parentPlantTag`,(select `lp`.`relationshipType` from `vplantlineage` `lp` where `lp`.`childPlantId` = `p`.`plantId` limit 1) AS `parentRelationshipType`,case when exists(select 1 from `vplantlineage` `lc` where `lc`.`parentPlantId` = `p`.`plantId` limit 1) then 1 else 0 end AS `hasChildren` from (((((((((`plant` `p` left join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) left join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join `plantlocationhistory` `clh` on(`clh`.`plantLocationHistoryId` = (select `plh`.`plantLocationHistoryId` from `plantlocationhistory` `plh` where `plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 order by `plh`.`startDateTime` desc limit 1))) left join `location` `l` on(`l`.`locationId` = `clh`.`locationId`)) left join `flowering` `lf` on(`lf`.`floweringId` = (select `f`.`floweringId` from `flowering` `f` where `f`.`plantId` = `p`.`plantId` and `f`.`isActive` = 1 order by `f`.`startDate` desc limit 1))) left join `repotting` `lr` on(`lr`.`repottingId` = (select `r`.`repottingId` from `repotting` `r` where `r`.`plantId` = `p`.`plantId` and `r`.`isActive` = 1 order by `r`.`repotDate` desc limit 1))) left join `growthmedium` `gm` on(`gm`.`growthMediumId` = `lr`.`newGrowthMediumId`)) left join `plantevent` `lfeed` on(`lfeed`.`plantEventId` = (select `pe`.`plantEventId` from (`plantevent` `pe` join `observationtype` `o` on(`o`.`Id` = `pe`.`observationTypeId` and `o`.`isActive` = 1 and `o`.`typeCode` like 'OBS_FEED%')) where `pe`.`plantId` = `p`.`plantId` and `pe`.`isActive` = 1 order by `pe`.`eventDateTime` desc limit 1))) left join `observationtype` `ot` on(`ot`.`Id` = `lfeed`.`observationTypeId`)) where `p`.`isActive` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vtaxonidentity`
--

/*!50001 DROP VIEW IF EXISTS `vtaxonidentity`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`orchid`@`localhost` SQL SECURITY DEFINER */
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

-- Dump completed on 2026-05-20 21:38:06
