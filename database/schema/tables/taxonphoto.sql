CREATE TABLE IF NOT EXISTS `taxonphoto` (
  `taxonPhotoId` int NOT NULL AUTO_INCREMENT,
  `taxonId` int NOT NULL,
  `fileName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `thumbnailFileName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mimeType` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `isPrimary` tinyint(1) NOT NULL DEFAULT '1',
  `isActive` tinyint(1) NOT NULL DEFAULT '1',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`taxonPhotoId`),
  KEY `fk_taxonphoto_taxon` (`taxonId`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

