USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE
VIEW `orchids`.`vplantcurrentlocation` AS

SELECT `plh`.`plantLocationHistoryId` AS `plantlocationhistoryId`
	,`orchids`.`plant`.`plantId` AS `plantId`
	,`loc`.`locationId` AS `locationId`
	,`loc`.`locationName` AS `locationName`
	,`loc`.`locationTypeCode` AS `locationTypeCode`
	,`plh`.`startDateTime` AS `locationStartDateTime`
	,`orchids`.`plant`.`plantTag` AS `plantTag`
	,`orchids`.`plant`.`plantName` AS `plantName`
	,`orchids`.`taxon`.`taxonId` AS `taxonId`
	,(
		CASE 
			WHEN (`orchids`.`taxon`.`isSystemManaged` = 1)
				THEN CONCAT (
						`orchids`.`genus`.`genusName`
						,' sp.'
						)
			WHEN (`orchids`.`taxon`.`speciesName` IS NOT NULL)
				THEN CONCAT (
						`orchids`.`genus`.`genusName`
						,' '
						,`orchids`.`taxon`.`speciesName`
						)
			WHEN (`orchids`.`taxon`.`hybridName` IS NOT NULL)
				THEN CONCAT (
						`orchids`.`genus`.`genusName`
						,' '
						,`orchids`.`taxon`.`hybridName`
						)
			ELSE `orchids`.`genus`.`genusName`
			END
		) AS `displayName`
	,`orchids`.`plant`.`endDate` AS `plantEndDate`
	,`plh`.`RowOrder` AS `RowOrder`
FROM (
	(
		(
			(
				`orchids`.`plant` JOIN `orchids`.`taxon` ON ((`orchids`.`taxon`.`taxonId` = `orchids`.`plant`.`taxonId`))
				) JOIN `orchids`.`genus` ON ((`orchids`.`genus`.`genusId` = `orchids`.`taxon`.`genusId`))
			) LEFT JOIN (
			SELECT `sub`.`plantLocationHistoryId` AS `plantLocationHistoryId`
				,`sub`.`plantId` AS `plantId`
				,`sub`.`locationId` AS `locationId`
				,`sub`.`startDateTime` AS `startDateTime`
				,`sub`.`endDateTime` AS `endDateTime`
				,`sub`.`moveReasonCode` AS `moveReasonCode`
				,`sub`.`moveReasonNotes` AS `moveReasonNotes`
				,`sub`.`plantLocationNotes` AS `plantLocationNotes`
				,`sub`.`createdDateTime` AS `createdDateTime`
				,`sub`.`isActive` AS `isActive`
				,`sub`.`updatedDateTime` AS `updatedDateTime`
				,`sub`.`RowOrder` AS `RowOrder`
			FROM (
				SELECT `lochistory`.`plantLocationHistoryId` AS `plantLocationHistoryId`
					,`lochistory`.`plantId` AS `plantId`
					,`lochistory`.`locationId` AS `locationId`
					,`lochistory`.`startDateTime` AS `startDateTime`
					,`lochistory`.`endDateTime` AS `endDateTime`
					,`lochistory`.`moveReasonCode` AS `moveReasonCode`
					,`lochistory`.`moveReasonNotes` AS `moveReasonNotes`
					,`lochistory`.`plantLocationNotes` AS `plantLocationNotes`
					,`lochistory`.`createdDateTime` AS `createdDateTime`
					,`lochistory`.`isActive` AS `isActive`
					,`lochistory`.`updatedDateTime` AS `updatedDateTime`
					,row_number() OVER (
						PARTITION BY `lochistory`.`plantId` ORDER BY `lochistory`.`startDateTime` DESC
						) AS `RowOrder`
				FROM `orchids`.`plantlocationhistory` `lochistory`
				WHERE (`lochistory`.`isActive` = 1)
				) `sub`
			WHERE (`sub`.`RowOrder` = 1)
			) `plh` ON ((`orchids`.`plant`.`plantId` = `plh`.`plantId`))
		) LEFT JOIN `orchids`.`location` `loc` ON (
			(
				(`plh`.`locationId` = `loc`.`locationId`)
				AND (`loc`.`isActive` = 1)
				)
			)
	)
WHERE (`orchids`.`plant`.`isActive` = 1)

