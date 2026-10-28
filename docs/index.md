# OrchidApp documentation

Use current guides below. For each procedure, check its stated implementation limits before acting. Implementation status and pending acceptance are tracked in the [code backlog](code-change-backlog.md).

## Develop and maintain

- [Developer machine and first run](development-setup.md), with [C16 evidence and remaining acceptance](maintenance/c16-developer-setup.md)
- [Contributing and validation](../CONTRIBUTING.md)
- [Reproducible feature checks and release evidence](testing-evidence.md), with [C20 validation](maintenance/c20-reproducible-checks.md)
- [Greenhouse CI execution-mode deduplication (CHAT-R04)](maintenance/ci-greenhouse-modes.md)
- [Migration runners and incomplete-upgrade handling](migration-runners.md)
- [Historical Linux package, application and recovery checks](historical-linux-upgrade.md), with [technical fixture review](maintenance/historical-linux-fixture-review.md) and [historical investigation](maintenance/historical-ledger-compatibility.md) and [reviewed adoption](maintenance/historical-linux-adoption.md), followed by [package/application/recovery evidence](maintenance/historical-linux-application-recovery.md)
- [Schema-only database creation and future migrations](database-creation.md), with [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md) and [C05 CI checks](maintenance/c05-ci-database-acceptance.md)
- [Architecture](architecture.md) and [temporal design](temporal-design.md)
- [Manual lifecycle closure and C11 upgrade acceptance](maintenance/c11-manual-closure.md)
- [Ended plant policy and C12 upgrade acceptance](maintenance/c12-ended-plant-policy.md)
- [Plant-event validation-message correction and checks (CHAT-R01–R03)](maintenance/event-validation-messages.md)
- [Structural transactions and C13 acceptance](maintenance/c13-structural-transactions.md)
- [History ordering and C14 acceptance](maintenance/c14-history-ordering.md)
- [Windows upgrade contract](windows-upgrade-contract.md)
- [Legacy migration reconciliation evidence](maintenance/c10-migration-reconciliation.md)
- [Windows backup source and archive compatibility](windows-backup-format.md)
- [Windows restore recovery evidence](maintenance/c08-restore-recovery.md)
- [Protected backup retention evidence](maintenance/c09-backup-retention.md)
- [Linux paired backup and recovery evidence](maintenance/c17-linux-paired-backup.md)
- [Documentation ownership and maintenance](documentation-map.md)
- [Code change backlog](code-change-backlog.md)
- [Release notes](../RELEASE_NOTES.md) and [third-party notices](../THIRD_PARTY_NOTICES.md)

## Install and protect data

Start each release/installation upgrade with the [Windows and Linux upgrade action checklist (C01–C20)](upgrade-checklist.md). It includes one-time actions, recurring verification, unfinished requirements and a per-machine completion record.

| Task | Guide |
| --- | --- |
| Install or upgrade a general Raspberry Pi/Linux deployment | [Linux installation](user-guides/linux/installation-upgrade.md) |
| Full Pi backup before upgrade | [Full backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) |
| Routine Linux data backup and isolated restore | [MariaDB runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) |
| Windows installation or upgrade | [Windows 01](user-guides/windows/01-InstallOrUpgradeOrchidAppOnWindows.docx) |
| Windows first use | [Windows 02](user-guides/windows/02-PrepareOrchidAppForFirstUse.docx) |
| Windows plant management | [Windows 03](user-guides/windows/03-AddAndManagePlantsInOrchidApp.docx) |
| Windows cloud backup | [Windows 04](user-guides/windows/04-ConfigureCloudBackupFolderInOrchidAppForWindows.docx) |
| Windows recovery | [Windows 05](user-guides/windows/05-RecoverOrchidAppOnReplacementWindowsComputer.docx) |
| Linux first use | [Linux 01](user-guides/linux/01-PrepareOrchidAppForFirstUseLinuxPi.docx) |
| Linux plant management | [Linux 02](user-guides/linux/02-AddAndManagePlantsInOrchidApp-LinuxPi.docx) |
| iPhone/iPad Home Screen client | [iOS client](user-guides/ios/home-screen-web-app.md) |
| Mac Safari Dock client | [Mac client](user-guides/macos/safari-web-app.md) |

## Application references

- [Formatted genus/taxon notes](rich-notes.md)
- [Return navigation](navigation.md)
- [Botanical and active-plant search](name-search.md)

## Owner's installation only

[Local greenhouse monitoring](local-installation/greenhouse-monitoring.md) covers bespoke data feeds, charts, costs and permissions for the owner's one installation. [Monitoring activation](environment-summary-platform.md) explains the default-off installation policy. No other installation should need these data objects, grants, importers or settings.

## History

[Documentation history](history/index.md) preserves superseded guides, recent delivery records, evidence and prior release publications. They are not current operating procedures. When a docs/ file is no longer applicable, move it into docs/history/, identify the replacement and update incoming current links. Follow [AGENTS.md](../AGENTS.md) and the ownership map when changing code or documents.

- [Photo policy, readiness and recovery](photo-handling.md) — C15/C19 metadata/orientation, request compensation and retained recovery records.
- [C15/C19 implementation and validation](maintenance/c15-c19-photo-handling.md).

- [Windows installer backup and recovery](windows-installer-recovery.md), with [C18 validation and limits](maintenance/c18-installer-upgrades.md).
