-- =====================================================
-- Database
-- =====================================================
CREATE DATABASE orchids;
USE orchids;

-- =====================================================
-- Tables
-- =====================================================
DROP TABLE IF EXISTS species;
CREATE TABLE species (
  speciesId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for species or hybrid',
  genus varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Canonical genus name (e.g. Phalaenopsis)',
  speciesName varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Species epithet (NULL for hybrids)',
  hybridName varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Registered hybrid name (NULL if unnamed or species)',
  growthCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured growth habit code',
  growthNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text notes about growth characteristics',
  speciesNotes text COLLATE utf8mb4_unicode_ci COMMENT 'General notes about this species or hybrid',
  isActive tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = usable, 0 = retired or deprecated',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  updatedDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (speciesId),
  KEY ixSpeciesGenus (genus),
  KEY ixSpeciesIsActive (isActive)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Taxonomic information for orchid species and hybrids.';

DROP TABLE IF EXISTS location;
CREATE TABLE location (
  locationId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for a physical location',
  locationName varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Human-readable location name',
  locationTypeCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Type of location (Greenhouse, House, Garden, etc)',
  locationNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text notes about this location',
  climateCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'General climate classification',
  climateNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text climate description',
  locationGeneralNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Other notes about the location',
  isActive tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = active location, 0 = retired',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  updatedDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (locationId),
  KEY ixLocationName (locationName),
  KEY ixLocationTypeCode (locationTypeCode),
  KEY ixLocationIsActive (isActive)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Locations where plants may be kept over time.';

DROP TABLE IF EXISTS plant;
CREATE TABLE plant (
  plantId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for individual plant',
  speciesId int DEFAULT NULL COMMENT 'Linked species or hybrid (NULL if unidentified)',
  plantTag varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Physical label on the pot',
  plantName varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional informal name',
  acquisitionDate date DEFAULT NULL COMMENT 'Date plant was acquired',
  acquisitionSource varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Where the plant was obtained from',
  isActive tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = currently in collection, 0 = no longer present',
  endReasonCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason plant left collection (Died, GivenAway, Split, etc)',
  endDate date DEFAULT NULL COMMENT 'Date plant left collection',
  endNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of plant end-of-life',
  plantNotes text COLLATE utf8mb4_unicode_ci COMMENT 'General grower notes for this plant',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  updatedDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (plantId),
  UNIQUE KEY uqPlantPlantTag (plantTag),
  KEY ixPlantSpeciesId (speciesId),
  KEY ixPlantIsActive (isActive),
  KEY ixPlantEndReasonCode (endReasonCode),
  CONSTRAINT fkPlantSpecies FOREIGN KEY (speciesId) REFERENCES species (speciesId) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orchid plants tracked in the collection.';

DROP TABLE IF EXISTS flowering;
CREATE TABLE flowering (
  floweringId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for flowering record',
  plantId int NOT NULL COMMENT 'Plant that flowered',
  startDate date NOT NULL COMMENT 'Date flowering started',
  endDate date DEFAULT NULL COMMENT 'Date flowering ended (NULL = currently flowering)',
  spikeCount int DEFAULT NULL COMMENT 'Number of flower spikes',
  flowerCount int DEFAULT NULL COMMENT 'Approximate number of flowers',
  floweringNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Grower notes about flowering quality',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (floweringId),
  KEY ixFloweringPlantStartDate (plantId,startDate),
  CONSTRAINT fkFloweringPlant FOREIGN KEY (plantId) REFERENCES plant (plantId) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flowering history per plant. Current flowering = endDate IS NULL.';

DROP TABLE IF EXISTS plantevent;
CREATE TABLE plantevent (
  plantEventId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant event',
  plantId int NOT NULL COMMENT 'Plant the event relates to',
  eventCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured event type (Watering, Feeding, Pest, etc)',
  eventDateTime datetime NOT NULL COMMENT 'Date and time of event (local time)',
  eventDetails text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text description of event',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (plantEventId),
  KEY ixPlantEventPlantDateTime (plantId,eventDateTime),
  KEY ixPlantEventEventCode (eventCode),
  CONSTRAINT fkPlantEventPlant FOREIGN KEY (plantId) REFERENCES plant (plantId) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='General-purpose event log for plant care and observations.';

-- NOTE:
-- plantsplit.parentPlantId and plantsplit.childPlantId currently have foreign keys
-- constraints to plant.plantId.
-- GitHub Issue created: #2 https://github.com/rayfeeney/OrchidApp/issues/2 
DROP TABLE IF EXISTS plantsplit;
CREATE TABLE plantsplit (
  plantSplitId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  parentPlantId int NOT NULL COMMENT 'Original plant that was split',
  childPlantId int NOT NULL COMMENT 'New plant created from the split',
  splitDate date NOT NULL COMMENT 'Date the split occurred',
  splitReasonCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  splitReasonNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of why the plant was split',
  splitNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about the split outcome',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (plantSplitId),
  UNIQUE KEY uqPlantSplitUniquePair (parentPlantId,childPlantId),
  KEY ixPlantSplitParent (parentPlantId,splitDate),
  KEY ixPlantSplitChild (childPlantId,splitDate),
  CONSTRAINT fkPlantSplitChild FOREIGN KEY (childPlantId) REFERENCES plant (plantId) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fkPlantSplitParent FOREIGN KEY (parentPlantId) REFERENCES plant (plantId) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- NOTE:
-- repotting.plantId currently has no foreign key
-- constraints to plant.plantId.
-- GitHub Issue created: #1 https://github.com/rayfeeney/OrchidApp/issues/1 
DROP TABLE IF EXISTS repotting;
CREATE TABLE repotting (
  repottingId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for repotting event',
  plantId int NOT NULL COMMENT 'Plant that was repotted',
  repotDate date NOT NULL COMMENT 'Date of repotting',
  oldMediumCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Previous potting medium',
  oldMediumNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Notes on previous medium condition',
  newMediumCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'New potting medium',
  newMediumNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Notes on new medium',
  potSize varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Pot size used',
  repotReasonCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for repotting',
  repotReasonNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for repotting',
  repottingNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Additional repotting notes',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (repottingId),
  KEY ixRepottingPlantRepotDate (plantId,repotDate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Repotting history per plant.';

DROP TABLE IF EXISTS plantlocationhistory;
CREATE TABLE plantlocationhistory (
  plantLocationHistoryId int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  plantId int NOT NULL COMMENT 'Plant being moved',
  locationId int NOT NULL COMMENT 'Location plant is moved to',
  startDateTime datetime NOT NULL COMMENT 'Date and time plant entered this location',
  endDateTime datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  moveReasonCode varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for movement',
  moveReasonNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for movement',
  plantLocationNotes text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about this placement',
  createdDateTime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (plantLocationHistoryId),
  KEY ixPlantLocationHistoryPlantTime (plantId,startDateTime,endDateTime),
  KEY ixPlantLocationHistoryLocationTime (locationId,startDateTime,endDateTime),
  CONSTRAINT fkPlantLocationHistoryLocation FOREIGN KEY (locationId) REFERENCES location (locationId) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fkPlantLocationHistoryPlant FOREIGN KEY (plantId) REFERENCES plant (plantId) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';


-- =====================================================
-- Views
-- =====================================================
DROP VIEW IF EXISTS plantactivesummary;
CREATE VIEW plantactivesummary AS
    SELECT 
        p.plantId AS plantId,
        p.plantTag AS plantTag,
        p.plantName AS plantName,
        p.acquisitionDate AS acquisitionDate,
        p.acquisitionSource AS acquisitionSource,
        s.genus AS genus,
        s.speciesName AS speciesName,
        s.hybridName AS hybridName,
        pcl.locationName AS locationName,
        pcl.locationTypeCode AS locationTypeCode,
        pcl.locationStartDateTime AS locationStartDateTime
    FROM
        plant p
        LEFT JOIN species s ON s.speciesId = p.speciesId
        LEFT JOIN plantcurrentlocation pcl ON pcl.plantId = p.plantId
    WHERE
        p.isActive = 1;
        
DROP VIEW IF EXISTS plantcurrentlocation;
CREATE VIEW plantcurrentlocation AS
    SELECT 
        plh.plantId AS plantId,
        plh.locationId AS locationId,
        l.locationName AS locationName,
        l.locationTypeCode AS locationTypeCode,
        plh.startDateTime AS locationStartDateTime
    FROM
        plantlocationhistory plh
        JOIN orchids.location l ON l.locationId = plh.locationId
    WHERE
        plh.endDateTime IS NULL;
        
        
-- =====================================================
-- Routines
-- =====================================================