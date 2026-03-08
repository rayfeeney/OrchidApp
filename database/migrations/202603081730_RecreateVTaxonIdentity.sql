USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE
VIEW `orchids`.`vtaxonidentity` AS
    SELECT 
        `t`.`taxonId` AS `taxonId`,
        `t`.`genusId` AS `genusId`,
        `g`.`genusName` AS `genusName`,
        `t`.`speciesName` AS `speciesName`,
        `t`.`hybridName` AS `hybridName`,
        (CASE
            WHEN (`t`.`isSystemManaged` = 1) THEN CONCAT(`g`.`genusName`, ' sp.')
            WHEN
                ((`t`.`speciesName` IS NULL)
                    AND (`t`.`hybridName` IS NULL))
            THEN
                `g`.`genusName`
            WHEN (`t`.`speciesName` IS NOT NULL) THEN CONCAT(`g`.`genusName`, ' ', `t`.`speciesName`)
            ELSE CONCAT(`g`.`genusName`, ' ', `t`.`hybridName`)
        END) AS `displayName`,
        `t`.`taxonNotes` AS `taxonNotes`,
        `t`.`isActive` AS `isActive`,
        `t`.`isSystemManaged` AS `isSystemManaged`,
        `t`.`growthCode` AS `growthCode`,
        `t`.`growthNotes` AS `growthNotes`
    FROM
        (`orchids`.`taxon` `t`
        JOIN `orchids`.`genus` `g` ON ((`g`.`genusId` = `t`.`genusId`)))