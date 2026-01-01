
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
DROP TABLE IF EXISTS `plantlocationhistory`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantlocationhistory` (
  `plantLocationHistoryId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant location history row',
  `plantId` int NOT NULL COMMENT 'Plant being moved',
  `locationId` int NOT NULL COMMENT 'Location plant is moved to',
  `startDateTime` datetime NOT NULL COMMENT 'Date and time plant entered this location',
  `endDateTime` datetime DEFAULT NULL COMMENT 'Date and time plant left this location (NULL = current)',
  `moveReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for movement',
  `moveReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation for movement',
  `plantLocationNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about this placement',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`plantLocationHistoryId`),
  KEY `ixPlantLocationHistoryPlantTime` (`plantId`,`startDateTime`,`endDateTime`),
  KEY `ixPlantLocationHistoryLocationTime` (`locationId`,`startDateTime`,`endDateTime`),
  CONSTRAINT `fkPlantLocationHistoryLocation` FOREIGN KEY (`locationId`) REFERENCES `location` (`locationId`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fkPlantLocationHistoryPlant` FOREIGN KEY (`plantId`) REFERENCES `plant` (`plantId`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time-based history of where plants have been located.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

