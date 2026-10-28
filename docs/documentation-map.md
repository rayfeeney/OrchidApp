# Documentation ownership

Use one current owner for each subject. Other documents link to that owner rather than repeating its detailed procedure.

| Subject | Current owner | Related material |
| --- | --- | --- |
| Cross-platform upgrade actions and per-release completion | [C01–C20 upgrade checklist](upgrade-checklist.md) | Platform contracts/runbooks below; backlog owns implementation status |
| Project overview and starting links | [README](../README.md) | [Documentation index](index.md) |
| Development machine and first run | [Developer setup](development-setup.md) | [Contributing](../CONTRIBUTING.md), [C16 evidence](maintenance/c16-developer-setup.md) |
| Fresh schema creation and later migrations | [Database creation](database-creation.md) | [Architecture](architecture.md), contributor workflow, [C05 CI evidence](maintenance/c05-ci-database-acceptance.md) |
| Later migration execution and incomplete markers | [Migration runners](migration-runners.md) | [Creation contract](database-creation.md), [C04 evidence](maintenance/c04-migration-runners.md) |
| Contribution and validation | [CONTRIBUTING](../CONTRIBUTING.md) | Feature check commands in feature guides |
| Reproducible feature check inventory and evidence | [Testing/evidence](testing-evidence.md) | [C20 measured results](maintenance/c20-reproducible-checks.md), CI artifacts and platform upgrade acceptance |
| Architecture and temporal behaviour | [Architecture](architecture.md), [temporal design](temporal-design.md) | [C11 closure evidence](maintenance/c11-manual-closure.md), [C12 read-only policy](maintenance/c12-ended-plant-policy.md), [C13 transaction evidence](maintenance/c13-structural-transactions.md), [C14 history order](maintenance/c14-history-ordering.md); current source limits are explicit |
| Windows layout and migration contract | [Windows upgrade contract](windows-upgrade-contract.md) | [C10 reconciliation evidence](maintenance/c10-migration-reconciliation.md), Windows Word guides listed in the index |
| Windows backup source, archive compatibility, retention and interrupted restore recovery | [Windows backup format](windows-backup-format.md) | [C06/C07 evidence](maintenance/c06-c07-backup-source-and-format.md), [C08 evidence](maintenance/c08-restore-recovery.md), [C09 evidence](maintenance/c09-backup-retention.md), Windows 04/05 user guides |
| Linux installation and upgrades | [Linux installation](user-guides/linux/installation-upgrade.md) | [Full pre-upgrade backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) |
| Linux routine paired backup and restore | [Runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) | [C17 evidence](maintenance/c17-linux-paired-backup.md); distinguish data restore from whole-machine recovery |
| Shared plant workflows | Windows 03 and Linux 02 Word guides | Maintain shared wording together; platform launch/support details differ |
| Browser client setup | [iOS](user-guides/ios/home-screen-web-app.md), [macOS](user-guides/macos/safari-web-app.md) | These are clients, not server installations |
| Owner's bespoke monitoring | [Local monitoring](local-installation/greenhouse-monitoring.md) | [Current implementation scope](environment-summary-platform.md) |
| Pending implementation work | [Code backlog](code-change-backlog.md) | Stable IDs linked by current guides |
| Release history and retired documents | [Release notes](../RELEASE_NOTES.md), [history](history/index.md) | Recent delivery stages remain identifiable |

## Word guides and publication

The current user guides are maintained as .docx files. Matching editable Markdown sources are not present for all seven guides. Edit the Word originals, preserve useful illustrations, render and inspect all pages, and distribute PDFs only after checking the current version. Historic PDFs under history/releases/ remain fixed release snapshots. Do not change legal texts while updating descriptive third-party notice wording.

## Review and retirement

For a behaviour change, update the owner, its index entry and any affected platform guide. Check configuration names, code/script paths and acceptance steps. If implementation remains incomplete, describe the present limit and link its backlog ID. Move inapplicable/superseded docs to history, with a replacement pointer and corrected incoming links. Keep new change reports in docs/; retire them when their operating instructions are superseded, preserving evidence rather than silently rewriting recorded results.

## Photo policy ownership

[Photo handling and recovery](photo-handling.md) owns C15/C19 metadata, orientation, readiness and recovery-record procedures. [Validation evidence](maintenance/c15-c19-photo-handling.md) records measured checks. Windows/Linux guides link here; the upgrade checklist owns adoption actions.

## Installer backup ownership

[Windows installer backup and recovery](windows-installer-recovery.md) owns C18 mandatory snapshot, archive format, stopped-writer checks, read-only review/extraction and artifact signing evidence. [C18 evidence](maintenance/c18-installer-upgrades.md) records actual fixture scope; the upgrade checklist retains separate Windows/Linux release actions.
