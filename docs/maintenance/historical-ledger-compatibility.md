# Historical migration compatibility: CHAT-R10/R11

**Current status: resolved for this exact disposable specimen database through [reviewed structural adoption](historical-linux-adoption.md).** All 245 original ledger records are archived unchanged, the verified historical starting point is recorded, and four actual forward migrations pass with zero work on a second apply. The immutable specimen and all migration source files remain unchanged. The original read-only refusal below remains reproducible; the sections below preserve the investigation. A general live adoption command and full C18 packaged upgrade/recovery are not yet implemented.

## Findings

- The restored older ledger has 245 records and no modern baseline marker. All checksums are syntactically SHA-256 values.
- Against the Pi capture's own migration files, 27 existing files do not match their recorded hashes and one recorded migration file is missing. This is not introduced by the new verifier or by the current UI/CI fixes.
- Against the extracted Windows review source, 242 existing-file raw checksums differ, plus the same missing file. An LF/BOM diagnostic reduces the existing-file mismatch count to 27. Available current/captured SQL content matches after diagnostic byte-format normalisation; the normalised bytes were never supplied to the runner or written back.
- Separate in-memory LF/CRLF and UTF-8/BOM/UTF-16 diagnostics did not recover a matching tested format for the 27 captured-file mismatches. This is bounded evidence, not proof of the original cause or a licence to reconstruct a supposed applied file.
- A read-only audit of captured Git history/object data also did not recover those 28 entries. It reviewed 236 migration blobs reachable from the observed commit and 3,668 small blobs including unreachable objects, testing raw/CRLF forms. It matched 217 other ledger entries. Captured Git configuration, hooks and remotes were not executed/copied for this audit. This does not prove that another trusted old release/backup cannot contain the necessary artifacts.
- `.gitattributes` pins LF for the four newer C11–C15/C19 migration files but uses general text handling for older SQL. The runner intentionally checks raw bytes. Legacy source/package byte reproducibility therefore needs explicit review (CHAT-R11); blanket normalisation would itself change recorded byte identities.
- Actual `Apply-Migrations.ps1 -PlanOnly` against a new restored private database returned nonzero with an applied-checksum refusal. The older history and all base-table row counts were unchanged; no migration/application deployment was attempted. The owned container and volume were removed.

## Affected captured history entries

Names only are listed here. Per-file recorded/current/captured hashes are retained in the local read-only review evidence. No migration contents or credential values are added to this report.

| Applied entry | Captured-file result |
| --- | --- |
| `202602152206_AddObservationSystemTypes.sql` | Recorded checksum differs from captured file |
| `202602171812_DropPlantSplitConstraints.sql` | Recorded checksum differs from captured file |
| `202602171816_DropPlantSplitFields.sql` | Recorded checksum differs from captured file |
| `202602171822_AddPlantSplitFields.sql` | Recorded checksum differs from captured file |
| `202602171824_AddPlantSplitConstraints.sql` | Recorded checksum differs from captured file |
| `202602171827_CreatePlantSplitChild.sql` | Recorded checksum differs from captured file |
| `202602172023_CreateSpSplitPlant.sql` | Recorded checksum differs from captured file |
| `202602172219_AlterPlant.sql` | Recorded checksum differs from captured file |
| `202602182031_FixVPlantLifecycleHistoryCollation.sql` | Recorded checksum differs from captured file |
| `202602182157_RecreateSpSplitPlant.sql` | Recorded checksum differs from captured file |
| `202602191800_RecreateSpSpiltPlant.sql` | Recorded checksum differs from captured file |
| `202602191815_RecreateSpSpiltPlant.sql` | Recorded checksum differs from captured file |
| `202602191830_RecreateSpSplitPlant.sql` | Recorded checksum differs from captured file |
| `202602192148_AlterVPlantActiveSummary.sql` | Recorded checksum differs from captured file |
| `202602192200_AlterVPlantCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602201200_AlterVPlantCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602201225_AlterVPlantCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602201436_AddVPlantActiveCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602201810_RecreateSpSplitPlant.sql` | Recorded checksum differs from captured file |
| `202602202120_CreateSpUpdatePlantDetails.sql` | Recorded checksum differs from captured file |
| `202602202150_AlterVPlantCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602210912_AlterVPlantCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602210918_AddVPlantActiveCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602210930_AddVPlantActiveCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602210935_AlterVPlantActiveCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602211000_AlterVPlantActiveCurrentLocation.sql` | Recorded checksum differs from captured file |
| `202602211420_AlterSpUpdatePlantDetails.sql` | Recorded checksum differs from captured file |
| `202606031900_TestViewMigrationRunner.sql` | Missing from captured and current source |

## Required resolution

1. Establish the provenance of the recorded hashes and, where available, obtain the actual applied historical artifacts from trusted release/Git/backup evidence. Review what the missing test-view entry did and the actual restored schema/state. Do not infer correctness solely from similar SQL text.
2. Decide and document a supported adoption/compatibility route for this older release under the migration contract. Any new adoption mechanism needs explicit evidence, a recoverable backup and matching operational/Desktop policy tests where applicable; it must preserve old applied records and the immutable specimen.
3. Establish how supported packaging/checkouts preserve the necessary historical byte identities across Windows and Linux. Do not rewrite applied SQL, substitute fixture-only migrations, remove ledger rows/files, relabel hashes, insert an invented baseline or relax checksum guards merely to obtain a green test.
4. Repeat the actual read-only runner. Only after it legitimately accepts the historical starting point should full package upgrade, once-only application, post-upgrade application actions, app-only update and failed-state recovery be tested.

The new tool is deliberately an observable refusal, not a workaround. A green fixture-verifier unit job or successful SQL restore does not demonstrate that the historical installation can be upgraded. The latest application's ordinary valid workflows are not implicated by this metadata/source compatibility finding.

See [historical Linux acceptance](../historical-linux-upgrade.md), [runner contract](../migration-runners.md) and [specimen technical review](historical-linux-fixture-review.md).

## Follow-up: published v1.2.1 and v1.2.0 artifacts

On 28 October 2026, the owner supplied [v1.2.1](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.2.1). GitHub records publication on 31 August 2026, with its current Linux asset uploaded on 13 September; the asset is evidence of those uploaded bytes, not proof they were present on the August publication date.

The downloaded Linux ZIP SHA-256 matched GitHub's asset digest: `f892a08c921dba5eb9f58eb19f007cae0aeb680f378183c043b9294dd1e7a73c`. Its 244 migration files recover exact raw-byte matches for 26 February entries previously incompatible with the captured Pi files. Across all 245 ledger entries, 28 match raw package bytes and another 215 match only a diagnostic LF/CRLF form. The tagged source (archive root commit prefix `91d4e0f`) has 217 raw matches plus 26 diagnostic CRLF matches. This confirms significant source/package line-ending differences. Diagnostic conversion is not accepted migration input and does not constitute an operational compatibility fix.

Two entries remain unresolved even after the tested line-ending forms:

- `202602182031_FixVPlantLifecycleHistoryCollation.sql`: present, but its checksum differs.
- `202606031900_TestViewMigrationRunner.sql`: absent from both v1.2.1 package and tagged source.

The earlier [v1.2.0 Linux package](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.2.0), SHA-256 `c6c580576ace99044658f0b06ec9463babfea36cb17f88b011f0acdb5d95464d` matching GitHub's asset digest, also has the same February mismatch. Its 12 absent entries include the later May/June migrations, consistent with its earlier contents; it does not recover the missing June test-view file.

These findings narrow the missing historical evidence from 28 entries to two, while leaving CHAT-R11 byte reproducibility and the actual canonical preflight refusal open. No downloaded release executable was run, no historical source/history was replaced, and the immutable specimen was unchanged. The earlier table records the captured-file findings; it is not a claim that all 28 remain unavailable from every source. Local machine-readable comparison evidence is retained separately from source/ZIP delivery.

## Follow-up: published v1.3.0

The owner requested [v1.3.0](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.3.0) be checked before further schema investigation. GitHub records publication on 16 October 2026. The Linux ZIP SHA-256 is `13ca9c8522983a8553ea1e9f99a8c7e0c133661c80e9fddf4bbda55494fd9096`, matching GitHub's asset digest. The source archive root identifies commit prefix `746825e`, distinct from the observed Pi checkout `080ba9c`.

Both Linux package and tagged source contain 244 migration files. The same February collation migration differs from the recorded checksum and the June test-view migration is absent. The Linux package has 28 raw matches plus 215 diagnostic line-ending matches; tagged source has 217 raw plus 26 diagnostic matches. Thus this release does not resolve the remaining two entries or the byte-format compatibility issue.

The package's `OrchidApp.Web.dll`, `.deps.json` and `.runtimeconfig.json` each differ byte-for-byte from the frozen Pi specimen. Different build/publish settings could explain some differences; these comparisons alone do not establish the specimen binary's source revision or a code defect. Published v1.3.0 must not be silently substituted for the installed Pi specimen or described as an identical build.

No executable from the download was run, no database was modified and no additional migration preflight was attempted. The next investigation remains a structural comparison of the actual specimen against historical schema artifacts, including later replacements of the February view and any evidence concerning the missing June entry.

## Owner clarification and February content review

The owner identifies `202606031900_TestViewMigrationRunner.sql` as uncontrolled work performed on the Pi and states no migration file will exist. This is owner-supplied provenance, not recovered SQL evidence. The desired outcome is to retire this entry from active upgrade accounting. No ledger row has been deleted. A supported cleanup/adoption implementation must preserve an audit record of the original entry and validate actual database state; the immutable specimen remains unchanged. It is no longer appropriate to keep requesting the nonexistent file as a prerequisite.

The available February file drops/recreates only `vplantlifecyclehistory`, combining observations, repotting, flowering and location changes. It contains no row-changing INSERT/UPDATE/DELETE statements, no explicit COLLATE clauses and no SET NAMES. It refers to historical `oldMediumCode`/`newMediumCode` repotting columns. Its filename alone therefore does not establish the collation fix originally executed. Later March migrations adapt the view to growth-medium IDs; the 8 March 17:23 replacement explicitly sets utf8mb4_unicode_ci and applies 13 COLLATE clauses. The 27 April 14:47 replacement retains this explicit collation handling. A later definition comparison is required; do not replay the February file against today's table structure.

The matching historical February payload has not been recovered. Editing after execution is one possible explanation for the checksum discrepancy; neither the precise edit nor its cause is established by available evidence. The recorded application time is 21 February 2026 17:11:58 (as stored, timezone not established), distinct from the filename's 18 February timestamp.


## Implemented resolution

See [reviewed adoption, complete structural comparison and actual acceptance](historical-linux-adoption.md). Historical bytes were not fabricated or relabelled. The June entry is retired from active planning while preserved in the original audit ledger. The exact final history view and complete bounded schema were independently checked; known old creation-context/index-name/text differences are explicitly pinned. Raw checksum protection continues for new forward migrations. This closes the immediate database blocker only for the identified isolated specimen.
