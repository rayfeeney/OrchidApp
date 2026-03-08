USE `orchids`;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE
VIEW `orchids`.`vlocationactivelist` AS
    SELECT 
        `orchids`.`location`.`locationId` AS `locationId`,
        `orchids`.`location`.`locationName` AS `locationName`,
        `orchids`.`location`.`locationTypeCode` AS `locationTypeCode`,
        `orchids`.`location`.`climateCode` AS `climateCode`
    FROM
        `orchids`.`location`
    WHERE
        (`orchids`.`location`.`isActive` = 1)