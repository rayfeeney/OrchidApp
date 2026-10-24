# Documentation ownership

Use one current owner for each subject. Other documents link to that owner rather than repeating its detailed procedure.

| Subject | Current owner | Related material |
| --- | --- | --- |
| Project overview and starting links | [README](../README.md) | [Documentation index](index.md) |
| Development machine and first run | [Developer setup](development-setup.md) | [Contributing](../CONTRIBUTING.md) |
| Fresh schema creation and later migrations | [Database creation](database-creation.md) | [Architecture](architecture.md), contributor workflow |
| Contribution and validation | [CONTRIBUTING](../CONTRIBUTING.md) | Feature check commands in feature guides |
| Architecture and temporal behaviour | [Architecture](architecture.md), [temporal design](temporal-design.md) | Current source limits are explicit |
| Windows layout and migration contract | [Windows upgrade contract](windows-upgrade-contract.md) | Windows Word guides listed in the index |
| Linux installation and upgrades | [Linux installation](user-guides/linux/installation-upgrade.md) | [Full pre-upgrade backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) |
| Linux routine backup and restore | [Runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) | Distinguish data restore from whole-machine recovery |
| Shared plant workflows | Windows 03 and Linux 02 Word guides | Maintain shared wording together; platform launch/support details differ |
| Browser client setup | [iOS](user-guides/ios/home-screen-web-app.md), [macOS](user-guides/macos/safari-web-app.md) | These are clients, not server installations |
| Owner's bespoke monitoring | [Local monitoring](local-installation/greenhouse-monitoring.md) | [Current implementation scope](environment-summary-platform.md) |
| Pending implementation work | [Code backlog](code-change-backlog.md) | Stable IDs linked by current guides |
| Release history and retired documents | [Release notes](../RELEASE_NOTES.md), [history](history/index.md) | Recent delivery stages remain identifiable |

## Word guides and publication

The current user guides are maintained as .docx files. Matching editable Markdown sources are not present for all seven guides. Edit the Word originals, preserve useful illustrations, render and inspect all pages, and distribute PDFs only after checking the current version. Historic PDFs under history/releases/ remain fixed release snapshots. Do not change legal texts while updating descriptive third-party notice wording.

## Review and retirement

For a behaviour change, update the owner, its index entry and any affected platform guide. Check configuration names, code/script paths and acceptance steps. If implementation remains incomplete, describe the present limit and link its backlog ID. Move inapplicable/superseded docs to history, with a replacement pointer and corrected incoming links. Keep new change reports in docs/; retire them when their operating instructions are superseded, preserving evidence rather than silently rewriting recorded results.
