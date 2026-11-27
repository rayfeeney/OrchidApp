# Linux-specific acceptance

Activity 08 uses the designated disposable Hyper-V guests. Start with `OrchidApp-Debian12`, Debian 12.15 x64 with MariaDB 10.11.19. The Debian 13/MariaDB 11.8 guest is the target environment. Keep it out of the current-version baseline run. The published v1.4.1 Linux package is ARM64, so record x64 source deployment, ARM64 emulation and physical Raspberry Pi evidence separately.

## Read-only baseline preflight

Copy `preflight.py` to the Debian 12 guest and, from that guest, run:

```sh
sudo python3 preflight.py
```

The script uses the guest's local MariaDB socket for read-only queries. It checks the guest identity, Debian version, architecture, systemd, the MariaDB server version and loopback listener, charset and collation, absence of application schemas and deployment files, and the .NET 8 SDK. Retain its JSON output before provisioning. A machine that differs from the recorded baseline requires review before deployment.

## Activity 08 work

- Use the [documented Linux deployment procedure](../../docs/user-guides/linux/installation-upgrade.md), canonical schema-only creation and migration runners. Verify startup, shutdown and restart through real systemd and run the [shared browser checks](../SharedBrowser.Checks/README.md).
- Exercise the [historical Linux specimen harness](../HistoricalUpgrade.Checks/README.md) for the frozen ARM64 fixture and apply the [paired backup and restore contract](../../docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) to the installed x64 guest.
- Keep monitoring disabled in general installation. Exercise the importer with synthetic CSV and a disposable opt-in database. Verify stored rows, repeat-input behaviour and actual systemd service and timer status.
- Reuse the [nightly and standby automation](../../docs/testing-evidence.md), using isolated data and local encrypted storage. Record what was verified through real systemd and which provider or device paths remain separate.
