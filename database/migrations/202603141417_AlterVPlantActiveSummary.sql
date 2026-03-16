SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW `vplantactivesummary` AS
SELECT 
    `p`.`plantId` AS `plantId`,
    `s`.`taxonId` AS `taxonId`,
    `p`.`plantTag` AS `plantTag`,
    `p`.`plantName` AS `plantName`,
    `p`.`acquisitionDate` AS `acquisitionDate`,
    `p`.`acquisitionSource` AS `acquisitionSource`,
    `g`.`genusName` AS `genusName`,
    `g`.`isActive` AS `genusIsActive`,
    `s`.`speciesName` AS `speciesName`,
    `s`.`hybridName` AS `hybridName`,
    (CASE
        WHEN (`s`.`isSystemManaged` = 1) THEN CONCAT(`g`.`genusName`, ' sp.')
        WHEN (`s`.`speciesName` IS NOT NULL) THEN CONCAT(`g`.`genusName`, ' ', `s`.`speciesName`)
        WHEN (`s`.`hybridName` IS NOT NULL) THEN CONCAT(`g`.`genusName`, ' ', `s`.`hybridName`)
        ELSE `g`.`genusName`
    END) AS `displayName`
FROM
    ((`plant` `p`
    JOIN `taxon` `s` ON (`s`.`taxonId` = `p`.`taxonId`))
    JOIN `genus` `g` ON (`g`.`genusId` = `s`.`genusId`))
WHERE
    (`p`.`isActive` = 1
     AND `p`.`endDate` IS NULL);
