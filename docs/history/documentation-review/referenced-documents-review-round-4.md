# Recent change records review — round 4

Baseline: OrchidApp-clean.zip. Reviewed 24 October 2026.

## Result

Reviewed all seven remaining files. The user confirms they were created within the last few days. They form a recent sequence of changes, not old documents that should be discarded because of age. Their relative sequence is evident in the instructions: 168-hour chart presentation, chart performance/cache work, whole-period net costs, then totals from available readings.

The source matches the latest available-readings policy. All three current SHA256 values in change-manifest.json match the baseline files exactly. Earlier notes still describe behaviour that later notes changed. The needed correction is explicit scope, supersession and provenance, with one current feature reference. No original files have been moved, deleted or edited.

## Findings

### R4-01 — Medium: Recent updates need an explicit sequence and supersession record

Files: CHART-UPDATE.md, PERFORMANCE-UPDATE.md, NET-COSTS-UPDATE.md and AVAILABLE-TOTALS-UPDATE.md.

The notes tell readers to apply files over a previous update, but do not identify baseline commits, delivery versions, archive filenames or dates. A new reader cannot reliably tell which instructions are current or whether the source already contains them. Recency does not make every stage simultaneously authoritative.

Recommended disposition: retain these as recent change/delivery records with a short stage identifier, baseline/result revision, and links to the previous/next record and current greenhouse-charts.md. Record unknown dates/revisions as unknown until verified; do not invent them from ZIP timestamps. When making the coordinated documentation changes, agree a location such as docs/changes/ for these records, with link updates. No move is made by this review.

### R4-02 — Medium: Two superseded descriptions contradict the checked-in implementation

CHART-UPDATE.md line 3 says provisional coverage is retained in tooltips. The current JavaScript tooltip callbacks show values/period text without the earlier technical coverage messages, consistent with the later net-cost update and current guide.

NET-COSTS-UPDATE.md line 11 says missing readings produce a dash and requires four valid 15-minute solar readings per UTC hour. AVAILABLE-TOTALS-UPDATE.md explicitly supersedes this: missing/null readings are skipped, no minimum coverage count is required, and both feeds absent can produce zero when a tariff is available. GreenhouseNetCostService.LoadAsync filters null/negative solar rows and aggregates available production; Build skips missing energy/production and does not impose four samples. The range is seven complete London calendar days and year-to-date through yesterday; the signed whole-period energy difference uses yesterday's applicable tariff.

Correction: preserve earlier statements as stage-specific history, clearly marked superseded. Make the current guide the single current definition. Do not accidentally restore the former completeness threshold during documentation cleanup or describe missing data as known zero measurements. A zero total from absent feeds is an available-data result, not proof of complete measurement.

### R4-03 — Medium: Source-patch delivery instructions need a platform and baseline boundary

All four notes use delivery-relative instructions such as “apply these files”, “included files” or “the accompanying patch”. None names a stable archive/patch. CHART-UPDATE.md refers to five files but supplies no inventory. AVAILABLE-TOTALS-UPDATE.md refers to three files; the adjacent manifest's source/test/guide entries fit that scope, but the note never points to it.

NET-COSTS-UPDATE.md line 3 directs replacement of a deployed build without a platform qualifier. Public Windows upgrades must use the installer under the existing contract. These notes may reasonably describe preparing a developer checkout, but should not be mistaken for an alternative public Windows upgrade process.

Correction: explicitly label the notes as source-delivery instructions for an identified baseline. Link their file manifest where available. Direct readers to the maintained platform publish/install/upgrade procedure after rebuilding, including the installer requirement for Windows. Do not apply these patches again to a checkout that already contains their result. “No additional grants” in the final delta means no additional grants beyond its prior net-cost prerequisite, not that a new deployment needs no solar-table permission.

### R4-04 — Medium: Benchmark evidence is useful but lacks enough identity to reproduce the recorded result precisely

Files: PERFORMANCE-UPDATE.md and greenhouse-performance-verification.txt.

The report captures concrete query plans: timestamp range-index access, primary-key lookup in the period path, 336 hourly rows, 29 period rows and a reported 150 ms uncached load. It ends with 52 passed greenhouse checks, consistent with the performance-stage note. Current PerformanceChecks.cs contains the matching synthetic-data generation and optional benchmark path, including rollback of the benchmark readings. This makes the report useful supporting evidence rather than redundant prose.

However, the report lacks a recorded source revision, run date, exact command/options, machine details and an explicit database version header. Its test-count total identifies a stage, not a current all-tests result; later stages added checks. This review did not rerun it and cannot certify the earlier run, the deployed database or Raspberry Pi timing. The report's own plan row estimates are not measured source-row counts.

Correction: retain the report as synthetic performance evidence. Add an evidence header with known provenance, command and environment, and link it from the relevant change record/current guide. Keep unknown provenance explicit. Future results should use a dated/revision-labelled evidence file rather than overwriting the historical timing silently. Do not convert the recorded 150 ms result into a deployed performance guarantee.

### R4-05 — Low: The change manifest is correct for current file bytes but is not a release or test certificate

File: change-manifest.json.

All paths exist, and all three current hashes match exactly:

| Path | Current SHA256 |
| --- | --- |
| src/OrchidApp.Web/Services/GreenhouseNetCostService.cs | ec86e9046b6edca6aff32299cb3cefde1af30baea0888373cd23b906620c4665 |
| tests/GreenhouseCharts.Checks/NetCostChecks.cs | 30dbb3691715c3552e1230cacbcea245e8ab890dc1c389e579a1efb761222ef5 |
| docs/greenhouse-charts.md | f91415b7facc7be286f8cac43290da147714279ecdd6c0ae77ad5539e7597cf5 |

The previousSha256 values cannot be verified from the supplied current snapshot alone. The manifest does not identify its baseline/result revision or stage and covers three files, not the entire chart implementation or a built release. It does not prove tests passed. Editing greenhouse-charts.md later will correctly make its current recorded hash cease to match; that is expected for a fixed delivery record, not a reason to silently regenerate historical hashes.

Correction: associate the manifest explicitly with the available-totals delivery and retain it unchanged as evidence of those bytes. If a new package needs a manifest, create a new labelled one with its own scope. Store future delivery manifests with their corresponding change record rather than one ambiguous root docs/change-manifest.json. Detailed computed values are also recorded in reference-links-level-4.json.

### R4-06 — Medium: The grant companion is an operational prerequisite, not evidence of a granted permission

File: grant-greenhouse-solar-read.sql, referenced by NET-COSTS-UPDATE.md and greenhouse-charts.md.

The file contains only SELECT access on the existing EnergyMonitoring.EnphaseInterval table for the two named local OrchidApp account identities. Its comments correctly say it must be run manually by an administrator for existing accounts. It does not provision EnergyMonitoring, collectors, heater mappings or tariffs, and does not show that any user's server has the permission. No SQL was executed during this review.

Correction: retain it as a maintained, linked operational companion. Explain how to identify the actual configured account and host identity, verify the target table/access and grant only to applicable existing accounts. Keep the platform boundary: supported monitoring queries run on Linux ARM/ARM64, rather than requiring this grant for every Windows install. Clarify the current guide's conflicting grant wording, as identified in round 3. Exact database/account state must be verified on the intended isolated deployment before claiming it is ready.

## Classification of all seven files

| File | Recommended role | Current status |
| --- | --- | --- |
| docs/CHART-UPDATE.md | Recent presentation-stage delivery record | Some tooltip wording superseded; preserve with stage/next-update link. |
| docs/PERFORMANCE-UPDATE.md | Recent performance-stage delivery record | Useful cache/query description; link its evidence and identify baseline. |
| docs/NET-COSTS-UPDATE.md | Recent net-cost-stage delivery record | Coverage policy superseded by available-totals stage; permission prerequisite still relevant. |
| docs/AVAILABLE-TOTALS-UPDATE.md | Latest available-readings change record | Calculation policy matches inspected source; connect to its manifest/current guide. |
| docs/greenhouse-performance-verification.txt | Supporting synthetic performance evidence | Keep stage-specific results; improve provenance without inventing it. |
| docs/change-manifest.json | Fixed three-file delivery manifest | Current hashes all verified; previous hashes unverified; not a release manifest. |
| docs/grant-greenhouse-solar-read.sql | Current operational companion | Exists and matches stated SELECT scope; execution/account state not verified. |

The recommended roles preserve useful recent work while preventing intermediate instructions from competing with the final guide. Classification is a recommendation; no file movement, rewrite or deletion has been performed.

## References and further review

All seven explicit local references/manifest entries checked in this round resolve to existing files. Repeated targets are counted per source occurrence in the reference inventory. The unnamed synthetic query-plan report resolves by matching content to greenhouse-performance-verification.txt; use an explicit link in the future. Unnamed patch/archive references remain unresolved delivery context, not newly discovered missing guide files.

No additional current documentation file was exposed by this round. The current documentation reference-chain content review and the queued unlinked-record classification pass are therefore complete. Earlier findings still stand. Historical release snapshots and bundled dependency/legal documentation were deliberately kept outside a current-guide rewrite; Word visual checks, external EnergyMonitoring provisioning material, and runtime/restore validation remain separate outstanding work.

## Validation and next action

Performed static source/reference checks, compared manifest SHA256 values, and verified original extracted archive members remain unchanged. Did not apply patches, build, run tests/benchmarks, grant permissions, change a database, deploy, or certify a restore. Attached-document instructions were treated as review material, not execution requests.

The next stage is a coordinated correction pass across the reviewed documents, supported by the earlier round reports. Establish document ownership, preserve recent delivery/evidence records with explicit scope, fix current-guide contradictions and broken pointers, and separate implementation prerequisites from edits. Onboarding and recovery procedures must be validated in isolated environments before being described as proven.
