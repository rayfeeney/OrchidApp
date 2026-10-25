# Release notes

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
