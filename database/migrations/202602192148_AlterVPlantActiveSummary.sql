USE orchids;

DROP VIEW IF EXISTS vplantactivesummary;

CREATE OR REPLACE
SQL SECURITY INVOKER
VIEW `orchids`.`vplantactivesummary` AS
    SELECT 
        `p`.`plantId` AS `plantId`,
        `s`.`taxonId` AS `taxonId`,
        `p`.`plantTag` AS `plantTag`,
        `p`.`plantName` AS `plantName`,
        `p`.`acquisitionDate` AS `acquisitionDate`,
        `p`.`acquisitionSource` AS `acquisitionSource`,
        `g`.`genusName` AS `genusName`,
        `s`.`speciesName` AS `speciesName`,
        `s`.`hybridName` AS `hybridName`,
        (CASE
            WHEN (`s`.`isSystemManaged` = 1) THEN CONCAT(`g`.`genusName`, ' sp.')
            WHEN (`s`.`speciesName` IS NOT NULL) THEN CONCAT(`g`.`genusName`, ' ', `s`.`speciesName`)
            WHEN (`s`.`hybridName` IS NOT NULL) THEN CONCAT(`g`.`genusName`, ' ', `s`.`hybridName`)
            ELSE `g`.`genusName`
        END) AS `displayName`
    FROM
        ((`orchids`.`plant` `p`
        JOIN `orchids`.`taxon` `s` ON ((`s`.`taxonId` = `p`.`taxonId`)))
        JOIN `orchids`.`genus` `g` ON ((`g`.`genusId` = `s`.`genusId`)))
    WHERE
        (`p`.`isActive` = 1)
        AND (`p`.`endDate` IS NULL);
