USE orchids;

DROP VIEW

IF EXISTS vplantcurrentlocation;
	CREATE
		OR REPLACE SQL SECURITY INVOKER VIEW vplantcurrentlocation AS

SELECT plh.plantLocationHistoryId AS plantlocationhistoryId
	,plant.plantId AS plantId
	,loc.locationId AS locationId
	,loc.locationName AS locationName
	,loc.locationTypeCode AS locationTypeCode
	,plh.startDateTime AS locationStartDateTime
	,plant.plantTag AS plantTag
	,plant.plantName AS plantName
	,taxon.taxonId AS taxonId
	,(
		CASE 
			WHEN (taxon.isSystemManaged = 1)
				THEN CONCAT (
						genus.genusName
						,' sp.'
						)
			WHEN (taxon.speciesName IS NOT NULL)
				THEN CONCAT (
						genus.genusName
						,' '
						,taxon.speciesName
						)
			WHEN (taxon.hybridName IS NOT NULL)
				THEN CONCAT (
						genus.genusName
						,' '
						,taxon.hybridName
						)
			ELSE genus.genusName
			END
		) AS displayName
	,plant.endDate AS plantEndDate
	,pp.filePath AS heroFilePath
	,plh.RowOrder AS RowOrder
FROM (
	(
		(
			(
				plant JOIN taxon ON ((taxon.taxonId = plant.taxonId))
				) JOIN genus ON ((genus.genusId = taxon.genusId))
			) LEFT JOIN (
			SELECT sub.plantLocationHistoryId AS plantLocationHistoryId
				,sub.plantId AS plantId
				,sub.locationId AS locationId
				,sub.startDateTime AS startDateTime
				,sub.endDateTime AS endDateTime
				,sub.moveReasonCode AS moveReasonCode
				,sub.moveReasonNotes AS moveReasonNotes
				,sub.plantLocationNotes AS plantLocationNotes
				,sub.createdDateTime AS createdDateTime
				,sub.isActive AS isActive
				,sub.updatedDateTime AS updatedDateTime
				,sub.RowOrder AS RowOrder
			FROM (
				SELECT lochistory.plantLocationHistoryId AS plantLocationHistoryId
					,lochistory.plantId AS plantId
					,lochistory.locationId AS locationId
					,lochistory.startDateTime AS startDateTime
					,lochistory.endDateTime AS endDateTime
					,lochistory.moveReasonCode AS moveReasonCode
					,lochistory.moveReasonNotes AS moveReasonNotes
					,lochistory.plantLocationNotes AS plantLocationNotes
					,lochistory.createdDateTime AS createdDateTime
					,lochistory.isActive AS isActive
					,lochistory.updatedDateTime AS updatedDateTime
					,row_number() OVER (
						PARTITION BY lochistory.plantId ORDER BY lochistory.startDateTime DESC
						) AS RowOrder
				FROM plantlocationhistory lochistory
				WHERE (lochistory.isActive = 1)
				) sub
			WHERE (sub.RowOrder = 1)
			) plh ON ((plant.plantId = plh.plantId))
		) LEFT JOIN location loc ON (
			(
				(plh.locationId = loc.locationId)
				AND (loc.isActive = 1)
				)
			)
	LEFT JOIN plantphoto pp ON pp.plantId = plant.plantId
		AND pp.isHero = 1
		AND pp.isActive = 1
	)
WHERE (plant.isActive = 1);

