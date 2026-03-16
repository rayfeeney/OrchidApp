# Taxonomy lifecycle audit

Generated: 2026-03-14 11:36:22
Schema root: database/schema
Include structural objects: False

## Summary

- High findings: 1
- Medium findings: 4
- Info findings: 29

## Routine: spAddGenus

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\routines\spAddGenus.sql

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 39
- Text: FROM genus

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 47
- Text: INSERT INTO genus (

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 73
- Text: vGenusId AS GenusId,

## Routine: spAddTaxonInternal

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\routines\spAddTaxonInternal.sql

### [High] IdentityCreation

- Rule: Identity creation must validate active genus and active taxon.
- Reason: This object appears to create plant or taxon identity but may not enforce taxonomy active-state.
- Line: 1
- Text: [object-level finding]

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 29
- Text: FROM genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 30
- Text: WHERE genusId = pGenusId;

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 34
- Text: SET MESSAGE_TEXT = 'Invalid genusId: genus does not exist';

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 43
- Text: genusId,

## Routine: spSetGenusActiveState

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\routines\spSetGenusActiveState.sql

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 13
- Text: SET MESSAGE_TEXT = 'GenusId is required.';

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 22
- Text: FROM genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 23
- Text: WHERE genusId = pGenusId;

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 32
- Text: FROM genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 33
- Text: WHERE genusId = pGenusId;

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 40
- Text: UPDATE genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 42
- Text: WHERE genusId = pGenusId;

## Routine: spSplitPlant

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\routines\spSplitPlant.sql

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 75
- Text: JOIN genus g

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 76
- Text: ON t.genusId = g.genusId

## Routine: spUpdateGenus

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\routines\spUpdateGenus.sql

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 38
- Text: FROM genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 41
- Text: AND genusId <> pGenusId

### [Info] DirectGenusReference

- Rule: Direct genus reference.
- Reason: Useful for manual review.
- Line: 47
- Text: UPDATE genus

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 51
- Text: WHERE genusId = pGenusId;

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 60
- Text: SELECT pGenusId AS GenusId;

## View: vplantactivecurrentlocation

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\views\vplantactivecurrentlocation.sql

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantactivecurrentlocation` AS select `p`.`plantId` AS `plantId`,`t`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,(case when (`t`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when (`t`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`t`.`speciesName`) when (`t`.`hybridName` is not null) then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end) AS `displayName`,`pp`.`filePath` AS `heroFilePath` from (((((`plant` `p` join `taxon` `t` on((`t`.`taxonId` = `p`.`taxonId`))) join `genus` `g` on((`g`.`genusId` = `t`.`genusId`))) left join (select `sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,row_number() OVER (PARTITION BY `lochistory`.`plantId` ORDER BY `lochistory`.`startDateTime` desc )  AS `RowOrder` from `plantlocationhistory` `lochistory` where (`lochistory`.`isActive` = 1)) `sub` where (`sub`.`RowOrder` = 1)) `plh` on((`p`.`plantId` = `plh`.`plantId`))) left join `location` `loc` on(((`loc`.`locationId` = `plh`.`locationId`) and (`loc`.`isActive` = 1)))) left join `plantphoto` `pp` on(((`pp`.`plantId` = `p`.`plantId`) and (`pp`.`isHero` = 1) and (`pp`.`isActive` = 1)))) where ((`p`.`isActive` = 1) and (`p`.`endDate` is null));

### [Info] GenusActiveLogic

- Rule: Line contains genus and active-state logic.
- Reason: Likely relevant to the inactive-genus refactor.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantactivecurrentlocation` AS select `p`.`plantId` AS `plantId`,`t`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,(case when (`t`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when (`t`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`t`.`speciesName`) when (`t`.`hybridName` is not null) then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end) AS `displayName`,`pp`.`filePath` AS `heroFilePath` from (((((`plant` `p` join `taxon` `t` on((`t`.`taxonId` = `p`.`taxonId`))) join `genus` `g` on((`g`.`genusId` = `t`.`genusId`))) left join (select `sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,row_number() OVER (PARTITION BY `lochistory`.`plantId` ORDER BY `lochistory`.`startDateTime` desc )  AS `RowOrder` from `plantlocationhistory` `lochistory` where (`lochistory`.`isActive` = 1)) `sub` where (`sub`.`RowOrder` = 1)) `plh` on((`p`.`plantId` = `plh`.`plantId`))) left join `location` `loc` on(((`loc`.`locationId` = `plh`.`locationId`) and (`loc`.`isActive` = 1)))) left join `plantphoto` `pp` on(((`pp`.`plantId` = `p`.`plantId`) and (`pp`.`isHero` = 1) and (`pp`.`isActive` = 1)))) where ((`p`.`isActive` = 1) and (`p`.`endDate` is null));

### [Medium] SelectionView

- Rule: Selection-facing views should usually exclude inactive genus/taxon.
- Reason: This view mentions genus/taxon but no obvious active-state filter was detected.
- Line: 1
- Text: [object-level finding]

## View: vplantactivesummary

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\views\vplantactivesummary.sql

### [Info] GenusActiveLogic

- Rule: Line contains genus and active-state logic.
- Reason: Likely relevant to the inactive-genus refactor.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantactivesummary` AS select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,(case when (`s`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when (`s`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`s`.`speciesName`) when (`s`.`hybridName` is not null) then concat(`g`.`genusName`,' ',`s`.`hybridName`) else `g`.`genusName` end) AS `displayName` from ((`plant` `p` join `taxon` `s` on((`s`.`taxonId` = `p`.`taxonId`))) join `genus` `g` on((`g`.`genusId` = `s`.`genusId`))) where ((`p`.`isActive` = 1) and (`p`.`endDate` is null));

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantactivesummary` AS select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,(case when (`s`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when (`s`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`s`.`speciesName`) when (`s`.`hybridName` is not null) then concat(`g`.`genusName`,' ',`s`.`hybridName`) else `g`.`genusName` end) AS `displayName` from ((`plant` `p` join `taxon` `s` on((`s`.`taxonId` = `p`.`taxonId`))) join `genus` `g` on((`g`.`genusId` = `s`.`genusId`))) where ((`p`.`isActive` = 1) and (`p`.`endDate` is null));

### [Medium] SelectionView

- Rule: Selection-facing views should usually exclude inactive genus/taxon.
- Reason: This view mentions genus/taxon but no obvious active-state filter was detected.
- Line: 1
- Text: [object-level finding]

## View: vplantcurrentlocation

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\views\vplantcurrentlocation.sql

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantcurrentlocation` AS select `plh`.`plantLocationHistoryId` AS `plantlocationhistoryId`,`plant`.`plantId` AS `plantId`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,`plant`.`plantTag` AS `plantTag`,`plant`.`plantName` AS `plantName`,`taxon`.`taxonId` AS `taxonId`,(case when (`taxon`.`isSystemManaged` = 1) then concat(`genus`.`genusName`,' sp.') when (`taxon`.`speciesName` is not null) then concat(`genus`.`genusName`,' ',`taxon`.`speciesName`) when (`taxon`.`hybridName` is not null) then concat(`genus`.`genusName`,' ',`taxon`.`hybridName`) else `genus`.`genusName` end) AS `displayName`,`plant`.`endDate` AS `plantEndDate`,`plh`.`RowOrder` AS `RowOrder` from ((((`plant` join `taxon` on((`taxon`.`taxonId` = `plant`.`taxonId`))) join `genus` on((`genus`.`genusId` = `taxon`.`genusId`))) left join (select `sub`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`endDateTime` AS `endDateTime`,`sub`.`moveReasonCode` AS `moveReasonCode`,`sub`.`moveReasonNotes` AS `moveReasonNotes`,`sub`.`plantLocationNotes` AS `plantLocationNotes`,`sub`.`createdDateTime` AS `createdDateTime`,`sub`.`isActive` AS `isActive`,`sub`.`updatedDateTime` AS `updatedDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,`lochistory`.`endDateTime` AS `endDateTime`,`lochistory`.`moveReasonCode` AS `moveReasonCode`,`lochistory`.`moveReasonNotes` AS `moveReasonNotes`,`lochistory`.`plantLocationNotes` AS `plantLocationNotes`,`lochistory`.`createdDateTime` AS `createdDateTime`,`lochistory`.`isActive` AS `isActive`,`lochistory`.`updatedDateTime` AS `updatedDateTime`,row_number() OVER (PARTITION BY `lochistory`.`plantId` ORDER BY `lochistory`.`startDateTime` desc )  AS `RowOrder` from `plantlocationhistory` `lochistory` where (`lochistory`.`isActive` = 1)) `sub` where (`sub`.`RowOrder` = 1)) `plh` on((`plant`.`plantId` = `plh`.`plantId`))) left join `location` `loc` on(((`plh`.`locationId` = `loc`.`locationId`) and (`loc`.`isActive` = 1)))) where (`plant`.`isActive` = 1);

### [Info] GenusActiveLogic

- Rule: Line contains genus and active-state logic.
- Reason: Likely relevant to the inactive-genus refactor.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vplantcurrentlocation` AS select `plh`.`plantLocationHistoryId` AS `plantlocationhistoryId`,`plant`.`plantId` AS `plantId`,`loc`.`locationId` AS `locationId`,`loc`.`locationName` AS `locationName`,`loc`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime`,`plant`.`plantTag` AS `plantTag`,`plant`.`plantName` AS `plantName`,`taxon`.`taxonId` AS `taxonId`,(case when (`taxon`.`isSystemManaged` = 1) then concat(`genus`.`genusName`,' sp.') when (`taxon`.`speciesName` is not null) then concat(`genus`.`genusName`,' ',`taxon`.`speciesName`) when (`taxon`.`hybridName` is not null) then concat(`genus`.`genusName`,' ',`taxon`.`hybridName`) else `genus`.`genusName` end) AS `displayName`,`plant`.`endDate` AS `plantEndDate`,`plh`.`RowOrder` AS `RowOrder` from ((((`plant` join `taxon` on((`taxon`.`taxonId` = `plant`.`taxonId`))) join `genus` on((`genus`.`genusId` = `taxon`.`genusId`))) left join (select `sub`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`sub`.`plantId` AS `plantId`,`sub`.`locationId` AS `locationId`,`sub`.`startDateTime` AS `startDateTime`,`sub`.`endDateTime` AS `endDateTime`,`sub`.`moveReasonCode` AS `moveReasonCode`,`sub`.`moveReasonNotes` AS `moveReasonNotes`,`sub`.`plantLocationNotes` AS `plantLocationNotes`,`sub`.`createdDateTime` AS `createdDateTime`,`sub`.`isActive` AS `isActive`,`sub`.`updatedDateTime` AS `updatedDateTime`,`sub`.`RowOrder` AS `RowOrder` from (select `lochistory`.`plantLocationHistoryId` AS `plantLocationHistoryId`,`lochistory`.`plantId` AS `plantId`,`lochistory`.`locationId` AS `locationId`,`lochistory`.`startDateTime` AS `startDateTime`,`lochistory`.`endDateTime` AS `endDateTime`,`lochistory`.`moveReasonCode` AS `moveReasonCode`,`lochistory`.`moveReasonNotes` AS `moveReasonNotes`,`lochistory`.`plantLocationNotes` AS `plantLocationNotes`,`lochistory`.`createdDateTime` AS `createdDateTime`,`lochistory`.`isActive` AS `isActive`,`lochistory`.`updatedDateTime` AS `updatedDateTime`,row_number() OVER (PARTITION BY `lochistory`.`plantId` ORDER BY `lochistory`.`startDateTime` desc )  AS `RowOrder` from `plantlocationhistory` `lochistory` where (`lochistory`.`isActive` = 1)) `sub` where (`sub`.`RowOrder` = 1)) `plh` on((`plant`.`plantId` = `plh`.`plantId`))) left join `location` `loc` on(((`plh`.`locationId` = `loc`.`locationId`) and (`loc`.`isActive` = 1)))) where (`plant`.`isActive` = 1);

### [Medium] SelectionView

- Rule: Selection-facing views should usually exclude inactive genus/taxon.
- Reason: This view mentions genus/taxon but no obvious active-state filter was detected.
- Line: 1
- Text: [object-level finding]

## View: vtaxonidentity

File: C:\Users\rfeen\source\repos\OrchidApp\database\schema\views\vtaxonidentity.sql

### [Info] GenusIdReference

- Rule: Direct genusId reference.
- Reason: Useful for tracing propagation of genus identity.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vtaxonidentity` AS select `t`.`taxonId` AS `taxonId`,`t`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,`t`.`speciesName` AS `speciesName`,`t`.`hybridName` AS `hybridName`,(case when (`t`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when ((`t`.`speciesName` is null) and (`t`.`hybridName` is null)) then `g`.`genusName` when (`t`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`t`.`speciesName`) else concat(`g`.`genusName`,' ',`t`.`hybridName`) end) AS `displayName`,`t`.`taxonNotes` AS `taxonNotes`,`t`.`isActive` AS `isActive`,`t`.`isSystemManaged` AS `isSystemManaged`,`t`.`growthCode` AS `growthCode`,`t`.`growthNotes` AS `growthNotes` from (`taxon` `t` join `genus` `g` on((`g`.`genusId` = `t`.`genusId`)));

### [Info] GenusActiveLogic

- Rule: Line contains genus and active-state logic.
- Reason: Likely relevant to the inactive-genus refactor.
- Line: 1
- Text: CREATE OR REPLACE VIEW `vtaxonidentity` AS select `t`.`taxonId` AS `taxonId`,`t`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,`t`.`speciesName` AS `speciesName`,`t`.`hybridName` AS `hybridName`,(case when (`t`.`isSystemManaged` = 1) then concat(`g`.`genusName`,' sp.') when ((`t`.`speciesName` is null) and (`t`.`hybridName` is null)) then `g`.`genusName` when (`t`.`speciesName` is not null) then concat(`g`.`genusName`,' ',`t`.`speciesName`) else concat(`g`.`genusName`,' ',`t`.`hybridName`) end) AS `displayName`,`t`.`taxonNotes` AS `taxonNotes`,`t`.`isActive` AS `isActive`,`t`.`isSystemManaged` AS `isSystemManaged`,`t`.`growthCode` AS `growthCode`,`t`.`growthNotes` AS `growthNotes` from (`taxon` `t` join `genus` `g` on((`g`.`genusId` = `t`.`genusId`)));

### [Medium] SelectionView

- Rule: Selection-facing views should usually exclude inactive genus/taxon.
- Reason: This view mentions genus/taxon but no obvious active-state filter was detected.
- Line: 1
- Text: [object-level finding]

