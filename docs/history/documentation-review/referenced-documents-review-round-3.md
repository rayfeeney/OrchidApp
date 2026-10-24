# Referenced documentation review — round 3

Baseline: OrchidApp-clean.zip. Reviewed 24 October 2026.

## Result and scope

All 14 queued documents received a content and reference review: seven Markdown files and seven Word guides. Current feature descriptions are largely supported by targeted source inspection. The main corrections concern Windows recovery/upgrade assurances, platform differences in first-use setup, greenhouse documentation that mixes several change stages, and incomplete release history.

No original guide or application file was changed. Word content, tables and external relationship targets were extracted for inspection. Paragraph numbers below identify the document XML paragraph sequence, including empty paragraphs and table cells; they are not page numbers. No Word layout render, screenshot-by-screenshot comparison, live application, database, installer, browser-device or restore test was performed. Existing statements about previously passed tests are not fresh results from this review.

## Findings

### R3-01 — High: Preserve the recovery ZIP before enabling writes to the cloud backup destination

Document: Windows 05 recovery guide, Quick checklist and step 5; related Windows 04 cloud guide, Run a backup now.

Recovery suggests configuring the cloud backup folder before restoring and describes it as allowing that folder to be used as the restore source. The launcher actually opens a general file picker; it neither requires the cloud setting nor sets the picker's initial directory from it. Configuring the folder alone does not immediately create/copy a backup, but subsequent backups replace the single cloud file `OrchidAppDataBackup.zip`. On a replacement machine, backing up the newly initialised empty collection before recovery could overwrite the intended recovery copy.

Correction: first download/copy the trusted ZIP to a separate recovery location and preserve it. Restore by choosing that file. Configure the future cloud backup destination only after verifying recovered data, then run a new backup. Explain that source-file selection and future backup destination are separate. Do not imply that merely selecting a folder already overwrites the file; the risk arises on a later backup/copy.

Evidence: `OrchidAppLauncherForm.cs`, RunRestoreAsync, ConfigureCloudBackupFolder and CopyLatestBackupToCloud; normal backup copy replaces the fixed destination filename.

### R3-02 — High: The recovery guide promises settings restoration that the current format does not deliver

Document: Windows 05 recovery guide, What the restore brings back, paragraphs 112–113; related Windows 04 cloud guide, What is stored in the backup.

The recovery table includes relevant launcher/backup settings. Current backups store settings at `launcher-settings/launcher-settings.json`; restore searches the ZIP extraction root for `launcher-settings.json`. This is the code mismatch confirmed in round 2. Including settings in a backup does not establish that the current restore consumes them.

Correction: fix and round-trip test format compatibility before promising restored settings. Until then, describe the supported limitations and required reconfiguration plainly. Preserve the useful post-restore checks for plants, photos and history, and add settings/backup destination verification. The final sentence that recovery is complete when plant records are visible is too weak for the fuller checklist earlier in the guide.

### R3-03 — High: Windows installation and release notes overstate legacy upgrade safety

Documents: Windows 01 installation guide, Important upgrade notes, paragraph 123; RELEASE_NOTES.md, Legacy migration behaviour and Backup behaviour.

The user guide says the launcher handles older data safely and creates a pre-upgrade backup first. Release notes call that backup legacy-source aware. Current source does require a backup command to succeed, but the command does not receive the discovered legacy root; the backup tool selects paths based on its own installed location. The contract already documents this gap and possible source/listener mismatches. Successful command execution is not proof that the discovered source was protected.

Correction: align current user guidance with the Windows contract and establish a validated legacy-upgrade path before presenting this as a reliable guarantee. Preserve the installer-led upgrade rule and instructions to retain old data and seek support for ambiguous layouts. Add an explicit verified-backup prerequisite for current same-layout upgrades too; there is no unconditional backup gate for every app-only update. Release history should retain its historical character but label inaccurate safety claims/corrections rather than continue serving them as current instructions.

### R3-04 — Medium: Recovery troubleshooting does not match launcher behaviour

Document: Windows 05 recovery guide, step 6 and troubleshooting.

The guide says the picker presents files in the backup location, but RunRestoreAsync uses a standard OpenFileDialog without a configured initial directory. It says closing a browser tab can make an unavailable restore button usable. Closing a browser tab does not stop the web process; the launcher controls button availability and stops the process after restore confirmation. A restore failure after stopping the web process can also leave buttons disabled, since the finally block re-enables them only if that process is still running.

Correction: tell users to browse explicitly to their preserved ZIP, explain the ready launcher state, and give a supported stop/reopen/support path for failed restore. Avoid repeated blind retries after partial replacement. Preserve the original recovery ZIP and diagnostic log. Fix step numbering: detailed steps currently jump from 1 to 3. Closing a tab is reasonable for avoiding accidental use during restore, but is not the mechanism that makes replacement safe.

### R3-05 — Medium: Linux first-use instructions inherit Windows bootstrap assumptions and numbering

Document: Linux 01 first-use guide, Start OrchidApp, paragraph 23; next-guide paragraph 97.

The Pi guide says first use may prepare the local database/supporting files and asks the user to wait. Ordinary Production startup does not perform Desktop bootstrap; Linux database/schema preparation is an installation responsibility. Waiting for Home does not repair a missing schema. The next guide is named “03 - Add and Manage Plants in OrchidApp”, but the Linux file is `02-AddAndManagePlantsInOrchidApp-LinuxPi.docx`.

Correction: state that an operator must complete installation/schema preparation and service verification before first-use setup. Point to the actual Linux guide with its Linux numbering. The Windows first-use bootstrap wording is appropriate to its host model. Both first-use guides can clarify that a genus's automatically created unidentified taxon can be used when the plant's species/hybrid is unknown, rather than presenting a named species/hybrid as an absolute minimum.

### R3-06 — Medium: The plant guides use an absolute read-only description for ended parents

Documents: Windows 03 and Linux 02 plant-management guides, split action summary and After a split (paragraphs 53, 191 and 213).

The guides say an ended parent is read-only. Main UI restrictions and some handlers support this as intended user behaviour, but the temporal reference correctly says ended-plant restrictions are not uniform across every event handler. Existing Event Edit and Remove handlers do not implement one common blanket ended-plant rejection. The description must not be treated as proof of uniform enforcement.

Correction: distinguish the intended supported workflows from current implementation coverage and verify the relevant edit/remove/photo paths. If strict read-only behaviour is a product requirement, close the enforcement gap separately. Preserve the explanation that splitting ends the parent and creates independent tagged children. Shared platform-neutral plant instructions are duplicated nearly verbatim; choose a shared source/maintenance process with explicit platform-specific sections rather than silently letting the two Word copies drift.

### R3-07 — Medium: Greenhouse guidance still reads like several appended delivery notes

Document: docs/greenhouse-charts.md, Scope and installation, Verification and earlier stage-specific verification sections.

The document tells readers to apply an “accompanying updated-files archive” without identifying or linking it. It mixes successive performance/presentation/net-cost changes and several historical test-count sets with a current operating reference. The later check inventory describes 28 calculation plus eight cache checks, while the program now also invokes NetCostChecks.Run and extra integration checks. Earlier totals may describe valid past stages, but are not clearly separated from current evidence or reproducible acceptance criteria.

Correction: rewrite around final behaviour, prerequisites, supported deployment and current validation commands. Remove archive-application directions from the current guide or point to a specific historical delivery artefact in a clearly historical section. Move dated measurements/results to identified evidence with build/revision, environment and command provenance. Do not claim that this review reproduced the recorded results. Keep the existing disposable-instance guard and the clear warning against production integration tests.

### R3-08 — Medium: Greenhouse permission and external-dependency guidance is inconsistent

Document: docs/greenhouse-charts.md, Additional read permission versus Scope and installation.

The first section correctly requires SELECT on EnergyMonitoring.EnphaseInterval and supplies a grant; the later scope section says the change does not alter users or grants. Distinguish “no automatic grant changes” from “an additional deployment permission is required”. The SQL file `docs/grant-greenhouse-solar-read.sql` exists and names both local accounts; the operator should use the applicable existing account identities rather than assume both exist.

The guide depends on an externally maintained EnergyMonitoring schema, effective device mappings, heater data, tariffs and solar readings. The OrchidApp checkout contains consumer queries and test fixture definitions, but no matching production collector/provisioning source. The Enphase FAQ supports the endpoint's 15-minute interval description; it does not establish which endpoint the user's external collector currently calls.

Correction: name the external system owner/provisioning reference and required contract/version or state that this material is outside this repo and must be supplied separately. Add deployment checks for actual tables, grants, mappings and readings. Do not adopt disposable fixture SQL as a production installer. Review the grant companion and change/evidence files in the final queue.

### R3-09 — Medium: Cache wording is broader than its implementation

Document: docs/greenhouse-charts.md, Performance update, statement that only successful results are cached and failures are not.

GreenhouseChartCache.GetValueAsync does not cache thrown/cancelled loads, but does store every normally returned result. GreenhouseNetCostService can return an Unavailable result for a missing/ambiguous tariff; this result is also cached. The blanket description can mislead someone diagnosing a corrected tariff or configuration that does not appear immediately.

Correction: distinguish exceptions/cancellation from returned domain-unavailable values and describe the lifetime for both. The configured 0–900 second clamp and default 120 seconds match source. Chart cache keys do not include a current day separately, but the chart range changes at London midnight, which supplies the intended key change. No new performance timing guarantee is established by static inspection.

### R3-10 — Medium: Release history is incomplete and sections are filed under the wrong release

Document: RELEASE_NOTES.md; version source: Directory.Build.props.

The checkout identifies product version 1.3.0, but release notes stop at 1.2.0. A “Completed upgrade-safety work” section explicitly about 1.2.0 is nested below the 1.1.0 heading, along with related installer/backup material. The claim that user guides are maintained as Markdown then converted through Word does not match the current tree: the seven user-guide Word files have no corresponding current Markdown sources.

Correction: add an accurately scoped 1.3.0 entry based on verified release changes; do not invent a release date from this review. Place 1.2.0 details under 1.2.0 and keep 1.1.0's ZIP-era instructions explicitly historical. State the actual maintained source and publication process. Historical guarantees about immutable lifecycles, stable same-day order, metadata stripping and end-to-end restore must not be promoted into current guarantees; link current contracts and record corrections where needed.

### R3-11 — Low: Browser-client guides mix reusable instructions with one incident's investigation

Documents: iOS Home Screen and macOS Safari Dock guides.

Manifest display/start URL, declared icon links and PNG dimensions match the checkout. Official WebKit and Apple references support the general presentation/icon descriptions; they do not resolve a particular Mac checkbox issue or establish device acceptance. The guides appropriately say device results remain pending.

However, both include a particular Tailscale address and the Mac guide includes a reported exact macOS version and troubleshooting incident. Most content is developer acceptance/investigation rather than a short end-user installation guide.

Correction: keep generic client setup with a placeholder for the operator-provided OrchidApp URL. Move the incident-specific address/version and research procedure to a clearly scoped troubleshooting/validation record under docs. Record actual supported/tested client versions after testing; do not infer a corrected version or universal Safari behaviour. Do not confuse a Home Screen/Dock client with a server deployment on those platforms.

### R3-12 — Low: Full Pi backup needs clearer execution prerequisites and whole-machine restore ownership

Document: Full-App-Backup-Pre-Upgrade.md.

The guide is more careful than the routine runbook: it stops writers, preserves application/configuration and service definitions, uses a protected archive, verifies an off-device hash and distinguishes integrity checking from a restore test. Retain those safeguards. It assumes rsync, MariaDB dump, tar/gzip and SCP are already available, and current shell blocks rely on the reader to notice failures rather than consistently guarding pipelines such as systemctl cat piped to tee. The companion runbook covers data restore, not a complete restoration of this app/config/service archive.

Correction: enumerate tool/account/access prerequisites, make required pipeline failures visible, and identify the supported recovery procedure/owner for restoring app configuration, service files, grants and versions from this bundle. Avoid restarting services simply to test a backup when the immediate next action is an upgrade. Its links to the current runbook and upgrade anchor resolve.

## Per-document disposition

| Document | Result |
| --- | --- |
| Full-App-Backup-Pre-Upgrade.md | Generally careful backup procedure; clarify prerequisites and full-bundle recovery route. |
| name-search.md | Query limits, grouping, active-plant filtering and collation descriptions match targeted source checks. No new confirmed content defect. |
| environment-summary-platform.md | OS/architecture policy and early query guard match source. Keep real-Pi validation requirement; it does not provision external monitoring. |
| ios/home-screen-web-app.md | Source metadata/assets match; separate client instructions from incident/acceptance work. |
| macos/safari-web-app.md | Keep pending-device-test caveat; separate the reported local incident from reusable setup. |
| RELEASE_NOTES.md | Add accurate current-version coverage, correct release nesting and actual publication-source description. |
| Windows 01 installation guide | Installer route broadly correct; correct legacy-backup assurance and add explicit pre-upgrade backup prerequisite. |
| Windows 02 first-use guide | Main setup sequence broadly matches source; clarify unidentified taxon option and maintain shared content consistently. |
| Windows 03 plant guide | Core care/split/propagation descriptions broadly match; qualify ended-parent enforcement and maintain shared content. |
| Windows 04 cloud guide | Correctly distinguishes local copy from completed provider sync; clarify backup cadence/overwrite and settings restore limits. |
| Windows 05 recovery guide | Recovery-source preservation, settings restoration, chooser/troubleshooting and completion criteria need correction. |
| Linux 01 first-use guide | Remove Desktop-bootstrap assumption and correct next-guide number. |
| Linux 02 plant guide | Shared content broadly matches; same ended-parent caveat as Windows guide. |
| greenhouse-charts.md | Calculations and platform gating largely match source; consolidate final behaviour, prerequisites, grants and evidence. |

Windows 04 correctly describes a startup-triggered seven-day check rather than a continuous timer, but should say that failures can occur and no launch means no new automatic backup. Preserve its instruction to verify the provider's remote copy. The single fixed-name cloud copy replaces the prior copy; cloud-provider version history is not an OrchidApp guarantee. Local backup success does not prove restore success.

## Reference checks

The seven Markdown documents contain 39 Markdown link occurrences: 36 local file/heading links and three external vendor references. Local targets and checked heading anchors resolve. The three vendor pages were fetched; no recursive audit of external sites was attempted:

- [WebKit Home Screen web apps](https://webkit.org/blog/13878/) supports touch-icon precedence.
- [Apple WWDC23 web apps](https://developer.apple.com/videos/play/wwdc2023/10120/) describes standalone presentation as configuration, not evidence of this installation's behaviour.
- [Enphase API FAQ](https://developer-v4.enphase.com/docs/faq) describes production_meter intervals, not the external collector's deployed configuration.

Word external relationship inspection found no external hyperlink relationships in these seven files. Cross-guide references are plain titles; intended files exist, but Linux numbering and some Windows title wording differ. These were checked by title as well as by filenames. No missing new concrete document file was identified. The greenhouse “accompanying archive” remains unresolved because no filename/link is given. Detailed results are in reference-links-level-3.json.

## Further review required

The current linked-guide chain is covered through this round. A final classification/consistency round is needed for four unlinked change reports and three supporting greenhouse/change files. These are not seven newly discovered operating guides; they must be classified as current instructions, dated evidence, historical delivery notes or redundant material before any move/removal. See the updated register for the exact seven paths.

Historical docs/release/v1.2.0 snapshots remain historical; no new current-guide dependency requires a full historical rewrite. Bundled third-party licence/readme texts remain distribution material. Legal/package conformance and visual/device acceptance are separate validation tasks, not hidden claims of this content review.

## Validation and next stage

Original archive members were compared by SHA256 with the extracted working copy after review; no baseline files were modified. Only review outputs and working extraction records were added under docs/reviews. No document instructions were executed as app/database commands.

After the final classification round, consolidate findings by document owner, separate code prerequisites from editorial corrections, and revise the current documentation together. Validate fresh developer setup, platform install/upgrade and backup/restore in isolated environments before calling the procedures proven. Visual Word/screenshot checks remain necessary when those guides are revised for publication.
