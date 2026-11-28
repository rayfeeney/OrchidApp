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

## Disposable x64 deployment and systemd

Publish the reviewed source with a locked dependency restore and framework-dependent Release publish. On the clean Debian 12 guest, run the deployment helper with sudo and point it at that source and publish directory:

```sh
sudo python3 tests/LinuxAcceptance.Checks/deploy.py --source . --publish /path/to/publish
```

The helper refuses existing fixture state. It creates a schema-only database and a dedicated non-root system account and uses a protected environment file with monitoring disabled. The service listens on guest loopback port 55308. It verifies readiness, stops the actual systemd unit, checks that its PID is zero, and starts it again. Follow the shared-browser README and use a loopback SSH tunnel if running Chromium on the Windows DEV PC. Record the browser platform separately from the application host.

On 28 November 2026, the designated Debian 12.15 x64 guest passed the preflight, locked .NET 8 restore/publish, canonical database creation and systemd stop/start with readiness. MariaDB was 10.11.19 and the schema ledger contained only `baseline:v1:202610271200`. Shared Chromium checks from Windows through the SSH tunnel passed against the deployed Linux service, including the large JPEG and HEIC uploads. Retained local evidence is under `dist/activity08-evidence/`. Post-write restart/reopen, importer, backup/standby and Linux upgrade checks remain separate.
