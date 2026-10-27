# Release notes

## C14 predictable history ordering

Plant history remains newest first. Matching timestamps now sort by event type: flowering, move, observation, repotting; matching events within one type use record ID descending. Date corrections can reposition cards. No schema, timestamp, configuration or migration change is required. See [C14 evidence](docs/maintenance/c14-history-ordering.md) and the [upgrade checklist](docs/upgrade-checklist.md).

## C13 CI revision v3 — metadata cache refresh

Lock-wait checks now leave enough idle time for MariaDB's transaction metadata cache to refresh. A fast persistent-observer regression exercises the stale-cache case that Windows process startup had masked. HTTP wait checks identify their actual blocker. This changes tests only; no migration or configuration change is required. Rerun CI and confirm `c13-lock-cache-v3` in its output. See the [cache diagnosis](docs/maintenance/c13-structural-transactions.md#ci-cache-diagnosis-and-revision-v3).

## C13 CI follow-up — lock-wait observation

Concurrency checks now accept a positive number of wait edges for the waiting connection, with a two-holder regression and clearer timeout diagnostics. Fresh subcase fixtures prevent cascaded failures after an earlier assertion. This changes tests only: no app, schema, migration or configuration update is required. Rerun the lifecycle CI job with revision `c13-lock-wait-count-v2`; see [C13 evidence](docs/maintenance/c13-structural-transactions.md#ci-follow-up-on-27-october-2026).

## C13 structural transaction rollback and concurrency

Plant writes now hold a shared parent-row lock through their request transaction, including event/photo operations racing with closure. Structural location, split, propagation and hero-photo procedures roll back failures without committing caller work. Existing databases require `202610262000_StructuralTransactions.sql` and the matching app; fresh creation uses the regenerated schema. No settings change or historical data repair is required. See [C13 evidence](docs/maintenance/c13-structural-transactions.md) and [Windows/Linux upgrade actions](docs/upgrade-checklist.md).

## C12 ended plants are read-only

Ended plants remain viewable but their details, events, photos and lifecycle dates cannot be changed through normal workflows. Event writes are checked on the server and scoped to the owning plant. Active-plant repotting date validation and flowering/location time preservation are corrected. Migration `202610261800_EndedPlantReadOnly.sql` also rejects ended detail/reactivation calls and protects propagation-origin acquisition dates. No historical dates are rewritten. See [C12 guidance](docs/maintenance/c12-ended-plant-policy.md) and the [upgrade checklist](docs/upgrade-checklist.md).

## Development database updates use existing .env credentials

With the development app stopped, `pwsh ./scripts/DevSetup/update-database.ps1` reads the repository `.env`, backs up the database outside the checkout and applies pending migrations. Retry the commit afterwards. The hook reads the same file through the developer export wrapper, so GUI credentials do not depend on terminal inheritance. The hook still blocks pending migrations and never applies them automatically. Production/Desktop configuration is unchanged. See [developer setup](docs/development-setup.md).

## C11 atomic manual plant closure

New migration `202610261200_AtomicManualPlantClosure.sql` fixes flowering closure and makes plant/location/flowering updates atomic, preserving a caller's existing transaction. Invalid open interval bounds are rejected; SQL failures are rolled back/rethrown. The existing ended-plant UI policy is unchanged. Historical partial closures are not automatically rewritten: follow the [C11 review and upgrade steps](docs/maintenance/c11-manual-closure.md) and [platform checklist](docs/upgrade-checklist.md).

## C17 Linux paired backup and recovery

Linux backups use explicit protected configuration and preserve each SQL snapshot with its own uploads and external settings. Stopped writers and a database read lock replace the previous online SQL/current-photo mirror assumption. Remote read-back precedes local retention; old cloud objects are not deleted. The matching isolated restore validates payloads, refuses nonempty targets and preserves a pending marker after partial failures. Existing deployments must configure the new entry points before scheduling; see the [Linux runbook](docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md).

## C09 protected backup retention

Normal backups now retain three verified routine ZIPs by default, with a minimum of one and an effective skip switch. Pre-upgrade, migration/restore safety copies and recorded recovery inputs are protected; unrelated or unrecognised files remain for review. Desktop database-update backups use a separate non-pruning directory. ZIP creation preserves empty directories and hidden files. See the [retention contract](docs/windows-backup-format.md#routine-backup-retention).

## C10 legacy migration reconciliation

Interrupted legacy copies now resume only missing, hash-verified files under recorded ownership. Completion waits for database identity and web readiness; failed startup retries readiness without recopying raw data. A verified target takes precedence over its unchanged preserved source. Changed/unrelated sources, residual targets and unsupported old state stop for review. See the [migration contract](docs/windows-upgrade-contract.md#migration-state-and-completion).

## C08 Windows restore recovery

Restore retains the selected ZIP and requires a verified safety backup before replacing data. Interrupted SQL/photo/settings replacement blocks normal startup and backups until an explicit recovery restores the retained input or original safety copy. Launcher cloud copies preserve recorded recovery inputs after restart. See the [recovery contract](docs/windows-backup-format.md#failure-and-acceptance-boundaries) for sequential replacement limits and support steps.

## C06+C07 - selected legacy source and backup settings compatibility

The launcher captures the detected legacy data without active writers, backs up that explicit captured root and migrates from the same staged data. Backup/restore verify MariaDB data-directory identity and reject unrelated listeners. New archives have versioned payload inventories; restore supports nested and older root settings paths, checks required components and validates photo references. Windows 04/05 passages now describe restored settings. Local source/format/database round trips passed; CI, installed-machine acceptance, partial-failure recovery, retention and migration-state reconciliation retain their stated limits. See [Windows backup contract](docs/windows-backup-format.md).

## C16 follow-up - ordinary Development startup

Development now reads the repository .env automatically and derives its app connection string from existing MariaDB values, so normal daily startup is dotnet run. An omitted upload setting uses a created per-user development directory. Explicit settings retain precedence. Production/Desktop ignore the development file. The optional configuration wrapper uses the same upload default. See [developer setup](docs/development-setup.md).

## C05 - schema creation and future-upgrade CI acceptance

CI now creates its canonical database through the production schema/seed manifest with no migration directory, then runs separate disposable creation/upgrade checks before export/drift comparison. Expanded checks verify required seeds, baseline identity, preserved records and a later migration applied once; missing seed/manifest, broken view order and partial imports must fail. Added the C# baseline policy check to CI and reused structured child errors in the database suite. Current-schema-to-future-migration coverage is locally verified; updated Linux CI and real older-installation fixtures remain separate acceptance. See [C05 evidence](docs/maintenance/c05-ci-database-acceptance.md).

## C16 - reproducible source development setup

Developer setup now uses one explicit MARIADB target to generate the app connection string, validates MariaDB/.NET tools and activates hooks. Committed development credentials and personal storage defaults are removed. The source-run wrapper restores the complete pinned Windows libvips runtime and verifies actual photo/thumbnail save and reopen before startup. Export requires explicit endpoints and ignores hidden native option files. The obsolete local MySQL Docker route now calls the supported disposable database suites. Added Windows/Linux native and configuration CI checks. See [setup instructions](docs/development-setup.md) and [local evidence/pending acceptance](docs/maintenance/c16-developer-setup.md).

## C04 CI follow-up - test error reporting

Database checks now compare the original child exception message returned as JSON, avoiding failures caused by wrapped/coloured PowerShell error displays. Added automatic protocol regression checks. Production migration and failed-DDL handling are unchanged.

## C04 - migration runner consistency

PowerShell entry points now share one runner and require explicit targets. Desktop uses matching preflight rules for duplicate timestamps, chronology, checksums and missing files, with documented baseline exceptions. Failed or uncertain SQL leaves a durable pending marker and blocks automatic retries. Developer workflow applies before exporting for review. See [runner instructions](docs/migration-runners.md) and [local evidence/CI limits](docs/maintenance/c04-migration-runners.md).

## CI test follow-up - Unix fixture arguments

Corrected the tool-resolution test to retain a one-item native argument array on Unix. Previously its scalar string was splatted into separate characters. Added an argument-count/type check and invocation diagnostics. Production tool resolution and database behaviour are unchanged.

## C01+C02 follow-up - Linux CI tool lookup

Corrected MariaDB tool lookup to return one executable when PATH exposes multiple matches such as /usr/bin and /bin. Added a duplicate-PATH regression check to the Linux schema CI job before export. Database schema and migration history are unchanged.

## C01+C02 - schema creation and baselines (local implementation)

Fresh setup uses a generated, checksummed schema manifest and required seeds without historical migration files. The retained rebuild.ps1 script no longer drops databases: it requires explicit confirmation and an absent/empty target. Desktop and PowerShell runners recognise the recorded schema cut-off and preserve legacy history. Export regenerates baseline metadata from recorded DB state. See [creation instructions](docs/database-creation.md) and [validation/pending Linux and native-photo acceptance](docs/maintenance/c01-c02-schema-baseline.md).

## C03 - monitoring isolation (local implementation)

Monitoring requires explicit Monitoring:Enabled=true and Linux ARM/ARM64. Distributed and absent settings default off. Preserve the owner private service override. See [evidence and pending device acceptance](docs/maintenance/c03-monitoring-isolation.md).

## v1.3.0 source snapshot and documentation correction

The supplied source declares public version 1.3.0 in Directory.Build.props. A verified public release date/change manifest was not supplied; this entry does not invent a release date or certify an existing installer. The source includes name search, formatted genus/taxon notes, client manifest/icons and recent bespoke greenhouse changes. The latter apply only to the owner's installation; explicit installation isolation remains pending code work.

This documentation correction clarifies schema-only new-database creation, later-migration scope, developer prerequisites, current recovery limits and document ownership. It adds the [open code backlog](docs/code-change-backlog.md), [maintenance rules](AGENTS.md), corrected platform guidance and [history](docs/history/index.md). No application/script/SQL/CI fixes or new release binaries are included. Runtime/setup/restore/device validation remains necessary.

## v1.2.0 Windows installer model 2026-05-24

Windows distribution moved to the installer model, separating replaceable application files (normally Program Files) from ProgramData user data. The launcher handles legacy discovery/copy and database startup; installer uninstall preserves ProgramData. Keep a verified recovery copy before upgrading. Current source-aware backup, partial migration and settings-restore limitations are in the [Windows contract](docs/windows-upgrade-contract.md) and backlog; earlier safety assertions must not be read as universal guarantees.

The fixed [v1.2.0 publication snapshot](docs/history/releases/v1.2.0/release-page.md) remains historical. The [previous combined release notes](docs/history/releases/release-notes-before-documentation-cleanup.md) preserve original wording and nesting, including v1.2.0 material formerly filed under v1.1.0.

## v1.1.0 Windows support 2026-05-16

The historical Windows ZIP release introduced local backup/cloud-folder workflows and platform guidance. Its ZIP deployment instructions are superseded for public Windows upgrades by the installer model. Do not copy a new ZIP over an installed app.

## v1.0.0 original availability record

The original release described the collection/lifecycle model, MariaDB schema export, web app, photos and Linux hosting. The historical record is preserved above. Current temporal, migration, image-metadata and recovery limits are described by the current contracts; the old guarantees are not evidence those limits were tested or fixed.
