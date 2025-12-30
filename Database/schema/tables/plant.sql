
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `plant`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plant` (
  `plantId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for individual plant',
  `speciesId` int DEFAULT NULL COMMENT 'Linked species or hybrid (NULL if unidentified)',
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
  KEY `ixPlantSpeciesId` (`speciesId`),
  KEY `ixPlantIsActive` (`isActive`),
  KEY `ixPlantEndReasonCode` (`endReasonCode`),
  CONSTRAINT `fkPlantSpecies` FOREIGN KEY (`speciesId`) REFERENCES `species` (`speciesId`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orchid plants tracked in the collection.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

