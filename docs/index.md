# OrchidApp documentation

Start here to find the current instructions. User guides are grouped by platform;
feature and design references live directly under `docs/`. MariaDB is the
supported database engine on Windows and Raspberry Pi/Linux. Legacy client or
environment-variable names in scripts are compatibility details, not support for
a separate MySQL deployment.

## Install, upgrade and recover

| Task | Guide |
| --- | --- |
| Install or upgrade a Raspberry Pi | [Linux installation and upgrades](user-guides/linux/installation-upgrade.md) |
| Back up the app, database, photos and configuration before a Pi upgrade | [Full pre-upgrade backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) |
| Configure routine Linux backups or restore data | [MariaDB backup and restore runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) |
| Add OrchidApp to an iPhone or iPad Home Screen | [iPhone and iPad web app](user-guides/ios/home-screen-web-app.md) |
| Install and validate a Safari Dock web app on Mac | [Safari Dock web app](user-guides/macos/safari-web-app.md) |
| Install or upgrade Windows | [Windows installation guide](user-guides/windows/01-InstallOrUpgradeOrchidAppOnWindows.docx) |
| Configure Windows cloud backups | [Windows backup guide](user-guides/windows/04-ConfigureCloudBackupFolderInOrchidAppForWindows.docx) |
| Recover onto a replacement Windows PC | [Windows recovery guide](user-guides/windows/05-RecoverOrchidAppOnReplacementWindowsComputer.docx) |

Additional illustrated first-use and plant-management guides are in
[Linux user guides](user-guides/linux/) and [Windows user guides](user-guides/windows/).

## Features

- [Formatted genus and taxon notes](rich-notes.md)
- [Back, Cancel and return navigation](navigation.md)
- [Genus, species and hybrid name search](name-search.md)
- [Environmental summary platform support](environment-summary-platform.md)

## Development and design

- [Project overview](../README.md)
- [Contribution and validation requirements](../CONTRIBUTING.md)
- [Architecture](architecture.md): system responsibilities and invariants.
- [Temporal design](temporal-design.md): lifecycle dates and ordering.
- [Windows upgrade contract](windows-upgrade-contract.md): installer and persistent data responsibilities.
- [Release notes](../RELEASE_NOTES.md)
- [Third-party notices](../THIRD_PARTY_NOTICES.md)

## Maintaining documentation

Update the existing guide when behaviour changes. Keep installation, upgrade,
backup and recovery instructions in `user-guides/<platform>/`; keep implementation
references under `docs/`. Avoid adding root-level patch readmes or lists of changed
files: Git records file changes and the release notes record release history.

Files under `release/` are historical release material, not current operating
instructions. Keep those snapshots, third-party licences and bundled component
readmes separate from current guides. Word guides remain alongside Markdown guides
because they are also distributed with the application.
