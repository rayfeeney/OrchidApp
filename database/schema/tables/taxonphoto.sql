CREATE TABLE IF NOT EXISTS `taxonphoto` (
  `taxonPhotoId` int(11) NOT NULL AUTO_INCREMENT,
  `taxonId` int(11) NOT NULL,
  `fileName` varchar(255) NOT NULL,
  `thumbnailFileName` varchar(255) NOT NULL,
  `mimeType` varchar(100) NOT NULL,
  `isPrimary` tinyint(1) NOT NULL DEFAULT 1,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`taxonPhotoId`)) ENGINE=InnoDB   ;

