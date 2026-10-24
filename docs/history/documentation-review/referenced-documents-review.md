# Referenced documentation review — round 2

Baseline: OrchidApp-clean.zip. Reviewed 24 October 2026.

## Scope and result

Reviewed the eight current guides directly referenced by README/CONTRIBUTING: index, architecture, temporal design, Windows upgrade contract, navigation, rich notes, Linux installation/upgrade, and the Linux MariaDB backup/restore runbook. Also reviewed the root third-party notices for internal scope and local file references. This is source consistency and usability review, not licence advice, installation certification or proof of a successful restore. Existing guides and application code are unchanged.

The design references are substantially more candid and precise than README. They already record real implementation limits. The largest remaining problems are in Linux setup/recovery instructions and inconsistencies between blanket architectural guarantees and their later caveats. The index points to real files but does not yet give a new developer an end-to-end setup route.

## Findings requiring changes

### R2-01 — High: Linux fresh installation invokes an incompatible rebuild script

Location: `docs/user-guides/linux/installation-upgrade.md:221–234`; implementation: `database/scripts/rebuild.ps1`.

The Linux guide instructs `pwsh ./database/scripts/rebuild.ps1`. That script requires `MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_USER`, `MARIADB_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_CHARSET` and `MARIADB_COLLATION`, but the preceding guide creates only a systemd environment file containing application connection/storage settings. It does not supply those seven script settings. More fundamentally, the script hard-codes `C:\Program Files\MariaDB 10.11\bin\mariadb.exe`. This is not a working Linux first-install path as written.

The script also applies views alphabetically despite the environmental view dependencies already handled specially by CI. This repeats and confirms round 1's bootstrap finding. Resolve the supported implementation first, then document and validate the actual Linux bootstrap. Remove the opening promise that following the present guide always produces a working system.

### R2-02 — High: Fresh-schema migration baselining has no operating procedure

Locations: Linux installation sections 3, 4.8 and 5.1; `docs/architecture.md:145–156`.

Architecture correctly states that a current-schema database must have its migration history aligned before future upgrades. The installation guide instead says the two strategies must never be combined on the same database and provides no baseline process. Its later upgrade instructions run all unrecorded migration filenames. The rebuild does not record baseline history, so a database installed from today's schema can be asked to replay historical DDL later.

Clarify that fresh creation and historical replay must not be combined, while a correctly baselined fresh installation must support future migrations. Establish a tested baseline operation rather than asking operators to invent history rows. This is a code/workflow prerequisite as well as a documentation correction.

### R2-03 — High: Upgrade credential provisioning is missing

Location: Linux installation/upgrade guide, section 5.1, line 362.

Upgrade commands source `/etc/orchidapp/orchidapp-migrations.env`, but no preceding setup step creates it or specifies its contents, ownership and access. Application settings in `orchidapp.env` do not replace the migration runner's `MARIADB_*` variables. The process-substitution command also lacks an explicit successful-read check before invoking the runner; a failed read should not allow accidental fallback to inherited credentials.

Document a separate, complete migration-account configuration and explicit database/server selection, check that loading succeeds, and then require the migration exit status to succeed. Keep application runtime and schema-change permissions distinct where appropriate. Do not include actual credentials in the guide or review output.

### R2-04 — High: Routine restore commands do not choose one backup

Locations: MariaDB backup/restore runbook, section 9 lines 226–242 and section 10 lines 292–308; actual backup naming in `infrastructure/backups/backup_orchids.sh`.

The test procedure copies the whole remote, decompresses all SQL archives, then redirects `~/restore_test/*.sql` into one client invocation. With multiple retained backups, Bash reports ambiguous redirection. The disaster-recovery procedure likewise copies the whole remote but then assumes `backup.sql.gz`; the script creates names such as `orchids_<date>_<time>.sql.gz`.

Choose and record one exact backup filename, retrieve it into a dedicated directory, decompress that file and import that file. Define how the operator selects a known-good snapshot. Keep the existing caution about SQL `CREATE DATABASE`/`USE` statements and isolated restore targets. Neither a matching filename nor SHOW TABLES is adequate proof of a restored application.

### R2-05 — High: Database snapshots and the current uploads mirror cannot promise historical collection recovery

Location: backup/restore runbook, section 3, especially line 51; backup script dump and later `rclone sync` operations.

The runbook claims “Point-in-time recovery”, but the implementation retains periodic full SQL dumps and a single current uploads mirror. No binary-log replay process or matching historical photo snapshots is documented. An older database can refer to images no longer present in the latest mirror. Even the latest dump and later uploads sync are not one atomic snapshot while the app is writing.

Describe recovery to retained database snapshots accurately, state the filesystem consistency limit, and define a supported paired recovery procedure. Historical image snapshots or coordinated backup/quiescence require implementation or operational decisions. Do not substitute a documentation guarantee for those decisions. Expand restore validation to checking records, reference data, photo files, permissions, configuration and working app workflows.

### R2-06 — Medium: Backup setup is tied to an undeclared personal machine configuration

Locations: installation guide section 4.11; runbook sections 4–7; `infrastructure/backups/backup_orchids.sh:11–14`.

The script hard-codes backup/log directories below `/home/raymond-23`. Its first log write occurs before creating the backup directory. The runbook assumes configured crypt remotes rather than describing their creation, and names `/usr/local/bin/backup_orchids.sh` without showing the installation/copy step. Installation instead runs and schedules the repository copy. These paths may both work on a prepared machine but do not form one complete portable procedure.

Choose one script deployment location; document account/path configuration, writable directories, client aliases, credentials, rclone remote/key setup and the scheduling account. Ensure cron sees the same credentials and rclone config used in the manual test. Validate the configured script before claiming backups are installed.

### R2-07 — Medium: Recovery has a stale document pointer and an ambiguous redeployment sequence

Location: runbook section 10, line 326.

`docs/installation-upgrade.md` does not exist. The current file is `docs/user-guides/linux/installation-upgrade.md`; a sibling Markdown link would be appropriate here. More seriously, after restoring the database, “re-deploy application” must not direct an operator through a fresh-install section that drops/rebuilds that restored database. Identify precisely which prerequisites, publish, configuration and service steps apply during recovery. Explicitly preserve the restored database and uploads.

This is a plain-text document pointer, so a Markdown-link-only checker would miss it.

### R2-08 — Medium: Architecture still has absolute claims that conflict with its detailed caveats

Locations: `docs/architecture.md:265`, `:324`, `:443` and `:579`.

The lifecycle section says its rules are database-enforced without qualification, and the write-strategy section says stored procedures execute atomically. Temporal design correctly explains that lifecycle checks can be caller-dependent and that transaction statements alone do not prove complete rollback/concurrency behaviour. Align the summary wording with that distinction; do not remove the accurate caveats.

Architecture also presents the standard Windows install path as the implemented location, whereas the Windows contract correctly distinguishes the default from the selected install root. It still refers to four executable checks and omits the greenhouse project, repeating the round 1 validation-inventory issue.

### R2-09 — Medium: The index needs a developer route and a clearer feature inventory

Location: `docs/index.md:25–40`.

All its linked targets exist. However, the Development section links contracts and contribution rules without an end-to-end developer setup route; this remains unresolved after following the links. An existing `docs/greenhouse-charts.md` is absent from the feature list and should be reviewed before deciding whether it is current and should be indexed. Directory links to platform guides are useful but make the intended reading order less explicit than named task links.

Keep one authoritative owner per procedure. After the next round, link current setup/feature guides explicitly and distinguish host installation from browser-client setup on iOS/macOS. Do not index every patch report automatically.

### R2-10 — Low: Third-party notices retain obsolete feature-scope wording

Location: `THIRD_PARTY_NOTICES.md:10` and corresponding bundled Legal notice.

“Genus edit proof of concept” no longer matches the supported genus/taxon Add/Edit feature described in rich-notes.md and its source. Update the descriptive heading consistently in both notice copies, preserving all licence texts and notices. This is a confirmed stale description, not a conclusion about legal compliance. Packaged-only paths such as `Legal/mariadb/COPYING` must be checked in a built package; they are not expected at repository root.

## Per-document disposition and confirmed implementation gaps

| Document | Disposition |
| --- | --- |
| docs/index.md | Valid links; revise developer routing and review feature completeness. |
| docs/architecture.md | Generally useful and source-aware; qualify summary guarantees and fix inventory/default-path wording. |
| docs/temporal-design.md | Broadly consistent with inspected schema and handlers; retain its explicit implementation limits. |
| docs/windows-upgrade-contract.md | Broadly consistent with inspected installer, launcher and scripts; known code gaps need separate remediation. |
| docs/navigation.md | Shared helper/filter and documented check project match the description in targeted inspection. Keep acceptance checks; no new confirmed correction identified. |
| docs/rich-notes.md | Marker, sanitiser allowlist, storage limits and client fallback match targeted source inspection. Keep acceptance/rollback guidance; no new confirmed correction identified. |
| docs/user-guides/linux/installation-upgrade.md | Not a complete executable fresh-install or upgrade procedure; high-priority corrections above. |
| docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md | Snapshot selection, recovery consistency, deployment setup and stale pointer need correction. |
| THIRD_PARTY_NOTICES.md | Stale feature label; preserve licence material and verify packaged destinations separately. |

The temporal reference accurately flags `spUpdatePlantDetails` writing `flowering.endDateTime` when the table defines `endDate`. It also accurately distinguishes flowering edits replacing times, repotting edits preserving times, and date-only location edits. These are application/database issues already documented, not new requests to alter behaviour.

The Windows contract accurately identifies the installed backup tool selecting its own app-root legacy paths rather than receiving the discovered source, the backup/restore settings path mismatch (`launcher-settings/launcher-settings.json` versus archive-root lookup), and inconsistent pruning parameters. Targeted source checks confirm those gaps remain. Do not rewrite user guides to promise successful legacy migration, settings restore or reliable retention before these workflows are corrected and validated.

Architecture accurately contradicts README's metadata-stripping guarantee: PhotoPipeline does not consume StripGpsMetadata or explicitly request metadata stripping in its JPEG save call. Add this correction to the coordinated README rewrite; do not advertise privacy behaviour as verified from an unused setting.

Linux prerequisites do not specify a Raspberry Pi OS release/architecture or package-repository preparation. Package availability was not checked online in this source review. Validate those prerequisites on the selected supported image rather than asserting that every named apt package is available by default. The loose importer setup notes near the beginning of installation-upgrade.md should move into an optional ordered procedure, with its service/configuration dependencies reviewed next. Troubleshooting should check secret configuration without printing credentials into logs or copied support output.

## References and follow-up boundary

Checked all 37 local Markdown link occurrences in this round; all targets exist, including the architecture anchor. Also checked plain-text document pointers, identifying the stale runbook path above. These results cover local references, not external vendor URLs or every possible anchor in the repository. The detailed link inventory is stored beside this report as `reference-links-level-2.json`.

New document targets and platform-directory contents are recorded in `review-register.md` for round 3. Historical release snapshots, generated review files, bundled dependency documentation and current operating guides remain separate categories. Following a cycle back to README or architecture does not require another full review unless later findings change their conclusions.

## Validation limits and next work

No database commands, hooks, installation, deployment, backup or restore operations were executed. Targeted source inspection supports the consistency findings but does not prove runtime, device, concurrency or recovery correctness. No guide or application source was changed.

Continue with the recorded round 3 queue, adding any genuinely new references it exposes. Once the current-guide reference chain is covered, resolve procedure/code prerequisites, agree document ownership, then update the affected guides and README/CONTRIBUTING together. Finally validate the documented onboarding and recovery paths in isolated environments.
