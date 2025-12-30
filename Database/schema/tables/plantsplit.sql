
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
DROP TABLE IF EXISTS `plantsplit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantsplit` (
  `plantSplitId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  `parentPlantId` int NOT NULL COMMENT 'Original plant that was split',
  `childPlantId` int NOT NULL COMMENT 'New plant created from the split',
  `splitDate` date NOT NULL COMMENT 'Date the split occurred',
  `splitReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  `splitReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of why the plant was split',
  `splitNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about the split outcome',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`plantSplitId`),
  UNIQUE KEY `uqPlantSplitUniquePair` (`parentPlantId`,`childPlantId`),
  KEY `ixPlantSplitParent` (`parentPlantId`,`splitDate`),
  KEY `ixPlantSplitChild` (`childPlantId`,`splitDate`),
  CONSTRAINT `fkPlantSplitChild` FOREIGN KEY (`childPlantId`) REFERENCES `plant` (`plantId`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fkPlantSplitParent` FOREIGN KEY (`parentPlantId`) REFERENCES `plant` (`plantId`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

