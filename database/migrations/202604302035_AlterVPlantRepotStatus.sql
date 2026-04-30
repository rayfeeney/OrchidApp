CREATE OR REPLACE VIEW vplantrepotstatus AS


SELECT base.plantId
	,base.plantTag
	,base.locationName
    ,base.genusId
	,base.genusName
	,base.displayName
	,base.acquisitionDate
	,base.lastRepotDate
	,COALESCE(base.acquisitionDate, base.lastRepotDate) AS effectiveRepotDate
	,base.monthsSinceRepot
	,CASE 
		WHEN base.lastRepotDate IS NULL
			AND base.acquisitionDate IS NULL
			THEN 'Unknown'
		WHEN base.lastRepotDate IS NOT NULL
			THEN 'Repotted'
		ELSE 'From acquisition'
		END AS repotStatus
	,CASE 
		WHEN base.lastRepotDate IS NULL
			AND base.acquisitionDate IS NULL
			THEN 'No repotting information'
		ELSE CONCAT (
				base.monthsSinceRepot
				,CASE 
					WHEN base.monthsSinceRepot = 1
						THEN ' month since '
					ELSE ' months since '
					END
				,CASE 
					WHEN base.lastRepotDate IS NOT NULL
						THEN 'repot'
					ELSE 'acquisition'
					END
				,' ('
				,DATE_FORMAT(base.effectiveDate, '%d/%m/%Y')
				,')'
				)
		END AS repotSummary
FROM (
	SELECT p.plantId
		,p.plantTag
		,l.locationName
		,g.genusName
        ,g.genusId
		,CASE 
			WHEN t.isSystemManaged = 1
				THEN CONCAT (
						g.genusName
						,' sp.'
						)
			WHEN t.speciesName IS NOT NULL
				THEN CONCAT (
						g.genusName
						,' '
						,t.speciesName
						)
			WHEN t.hybridName IS NOT NULL
				THEN CONCAT (
						g.genusName
						,' '
						,t.hybridName
						)
			ELSE g.genusName
			END AS displayName
		,p.acquisitionDate
		,repot.lastRepotDate
		,COALESCE(repot.lastRepotDate, p.acquisitionDate) AS effectiveDate
		,TIMESTAMPDIFF(MONTH, COALESCE(repot.lastRepotDate, p.acquisitionDate), CURDATE()) AS monthsSinceRepot
	FROM plant p
	INNER JOIN taxon t ON t.taxonId = p.taxonId
	INNER JOIN genus g ON g.genusId = t.genusId
	LEFT JOIN (
		SELECT r.plantId
			,MAX(r.repotDate) AS lastRepotDate
		FROM repotting r
		WHERE r.isActive = 1
		GROUP BY r.plantId
		) repot ON repot.plantId = p.plantId
	LEFT JOIN plantlocationhistory plh ON plh.plantId = p.plantId
		AND plh.isActive = 1
		AND plh.endDateTime IS NULL
	LEFT JOIN location l ON l.locationId = plh.locationId
	WHERE p.endDate IS NULL
	) base;
