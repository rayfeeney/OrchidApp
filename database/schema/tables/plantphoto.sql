CREATE TABLE IF NOT EXISTS `plantphoto` (
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
  CONSTRAINT `chkPlantPhotoIsHero` CHECK (`isHero` in (0,1))

) ENGINE=InnoDB   COMMENT='Photo metadata for Observation events. Image binaries are stored on disk; this table stores metadata only. Each photo belongs to exactly one plantEvent and one plant. At most one active hero photo per plant is permitted.';

