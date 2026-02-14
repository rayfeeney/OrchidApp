CREATE TABLE IF NOT EXISTS `plantphoto` (
  `plantPhotoId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for this plant photo record',
  `plantEventId` int NOT NULL COMMENT 'Observation event this photo is attached to',
  `plantId` int NOT NULL COMMENT 'Plant this photo belongs to (denormalised for direct access)',
  `fileName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Stored file name on disk',
  `filePath` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Relative server path to the stored image file',
  `mimeType` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'MIME content type of the stored file (e.g. image/jpeg)',
  `isHero` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = this photo is the plant hero image; at most one active hero per plant',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime DEFAULT NULL COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = active record; 0 = logically removed (soft delete)',
  `heroPlantId` int GENERATED ALWAYS AS ((case when ((`isHero` = 1) and (`isActive` = 1)) then `plantId` else NULL end)) STORED COMMENT 'Helper column used to enforce single active hero photo per plant',
  PRIMARY KEY (`plantPhotoId`),
  UNIQUE KEY `uxPlantPhotoSingleHero` (`heroPlantId`),
  KEY `fk_plantphoto_plant` (`plantId`),
  KEY `fk_plantphoto_plantevent` (`plantEventId`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Photo metadata for Observation events. Image binaries are stored on disk; this table stores metadata only. Each photo belongs to exactly one plantEvent and one plant. At most one active hero photo per plant is permitted.';

