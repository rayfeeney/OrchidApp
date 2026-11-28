# Linux-specific acceptance

Activity 08 uses the designated disposable Hyper-V guests. Start with `OrchidApp-Debian12`, Debian 12.15 x64 with MariaDB 10.11.19. The Debian 13/MariaDB 11.8 guest is the target environment. Keep it out of the current-version baseline run. The published v1.4.1 Linux package is ARM64, so record x64 source deployment, ARM64 emulation and physical Raspberry Pi evidence separately.

## Read-only baseline preflight

Copy `preflight.py` to the Debian 12 guest and, from that guest, run:

```sh
sudo python3 preflight.py
```

The script uses the guest's local MariaDB socket for read-only queries. It checks the guest identity, Debian version, architecture, systemd, the MariaDB server version and loopback listener, charset and collation, absence of application schemas and deployment files, and the .NET 8 SDK. Retain its JSON output before provisioning. A machine that differs from the recorded baseline requires review before deployment.

## Read-only target preflight

Run `sudo python3 preflight.py --target` only on `orchidapp-debian13`. This
mode checks Debian 13.8 x64, MariaDB server and client 11.8.9, systemd,
loopback binding, the recorded server character set and collation,
absence of application state, and the .NET 8 SDK. The default command
still selects the Debian 12 baseline.

The target preflight passed on 28 November 2026. Debian 13.8 x64 had
MariaDB server and client 11.8.9, utf8mb4/utf8mb4_unicode_ci, a loopback
database listener, systemd PID 1, .NET SDK 8.0.428 and no application
databases or installed fixture. Retained host evidence is
`dist/activity10-target-preflight.log`.

## Disposable x64 target deployment

After the Debian 13 preflight passes, publish the reviewed source as a
framework-dependent x64 build using the locked dependency restore.
Run `sudo python3 tests/LinuxAcceptance.Checks/deploy.py --target --source . --publish /path/to/publish`
on the target guest. The helper provisions the isolated
`orchids_activity10` database and `orchidapp-activity10.service`, listens
on guest loopback port 55310, and checks readiness before and after a
real systemd stop/start. Monitoring remains disabled.

The Debian 13.8/MariaDB 11.8.9 deployment passed on 28 November 2026
from `ba53587`. The locked build succeeded, the canonical schema and
seeds produced ledger entry `baseline:v1:202610271200`, and systemd
restarted the dedicated service to full readiness. Chromium on Windows
passed plant edits and large JPEG/HEIC uploads through the loopback
SSH tunnel. After a separate real restart it reopened the same plant,
both full-size photographs and their thumbnails. Retained evidence
is under `dist/activity10-target-*.log`.

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

On 28 November 2026, the designated Debian 12.15 x64 guest passed the preflight, locked .NET 8 restore/publish, canonical database creation and systemd stop/start with readiness. MariaDB was 10.11.19 and the schema ledger contained only `baseline:v1:202610271200`. Shared Chromium checks from Windows through the SSH tunnel passed against the deployed Linux service, including the large JPEG and HEIC uploads. Retained local evidence is under `dist/activity08-evidence/`. Post-write restart and Chromium reopen passed for the same plant, full-size images and thumbnails. Backup/standby and Linux upgrade checks remain separate.

## Opt-in importer fixture

Run `importer_check.py --source <reviewed-source> --python <fixture-venv>/bin/python` with sudo on the deployed Debian fixture. The Python environment needs MariaDB Connector/Python. The run on Debian 12 used 1.1.15 in a dedicated venv. The test calls the existing importer CSV path inside a real systemd oneshot service. It validates the deployment timer's schedule and service binding, then stops the test timer. It uses generated local CSV and an isolated schema. IMAP and provider behaviour remain outside this fixture.

On 28 November 2026 both imports succeeded. The same two reading IDs and values survived replay, with two completed audit entries and one distinct input file hash.

## Paired backup and socket-isolated restore

Run `paired_check.py --source <reviewed-source>` with sudo after the browser has created its fixture plant and photos. The runner checks the allowed database set before taking a server-wide read lock, stops the dedicated source service, calls the production paired backup tool and verifies encrypted local read-back. Recovery runs against a separately initialised MariaDB process with no TCP networking and events disabled. The runner recreates the expected locked schema definer for the isolated database and compares record, media and configuration witnesses. It restarts the source service and verifies readiness. The target application is outside this data-stage check.

On 28 November 2026 the initial backup passed, while restore stopped with MariaDB error 1449 because its target lacked the expected definer. The failed target and marker were retained. The corrected runner used a fresh target and passed the backup, encrypted read-back and restore comparisons. Four media files and one configuration file matched. Archive SHA-256 was `92df31836bb222970fcd0d21ce809fc9d7edd808d7d3a2fe57235895b069d60e`. The source restarted and passed readiness.

## Recovered application

The verified paired snapshot was used to start a second systemd web service on guest loopback port 55309. The rehearsal copied the stopped restored database and recovered uploads. It used a local socket, a fixture-only database account and fresh configuration with monitoring disabled. Both the source and recovered applications passed all readiness checks. The shared Chromium reopen check on Windows found plant 1 and verified both full-size photos and thumbnails against the recovered service. Retained evidence includes `activity08-recovered-check.log` and `recovered-browser-reopen.log`.

## Nightly backup and standby preparation

All 122 existing nightly and standby policy checks passed on Debian 12. Two one-shot systemd timers invoked the checked-in nightly backup and standby preparation tools. The backup captured the two disposable databases, verified encrypted local read-back and restarted the source application to readiness. Standby preparation selected the same snapshot and reached `PREPARED_RESTORE_PENDING`. The fixture deliberately left its email in the local outbox. The standby database stage requires MariaDB 11.8, so the Debian 12 run ended after verified preparation.

- Snapshot `orchidset-20261128T104050Z-eb16579180914edea0acaa812c4a39d6`
- SHA-256 `e86554128ea748727073409799c1314346472b214a54701d9f8683b3436471e2`
- Retained log `activity08-nightly-check.log`

The recovery and timer orchestration scripts used for these specific guest runs are retained with the local evidence. The existing production backup/standby commands and tracked test suites remain the reusable entry points.

## Historical specimen upgrade

[GitHub Actions run 46136490543](https://github.com/rayfeeney/OrchidApp/actions/runs/46136490543) passed on `f64e1527d48ef35e281dbe9c64b7544e3215668c`. It verified the frozen v1.3.0 ARM64 specimen with SHA-256 `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5`, preserved 245 historical ledger rows, applied four forward migrations and verified a no-op second apply. Plant actions, app-only package replacement, paired recovery and recovery after a deliberate migration failure passed. A separate restore in the same run passed operational adoption checks, including interruption, lock and password handling.

The workflow ran source-built ARM64 packages under emulation against isolated amd64 MariaDB 10.11.14. It used private local encrypted storage and a service-state adapter. The installed Debian 12 x64 results above used MariaDB 10.11.19 and real systemd. Physical Raspberry Pi, published v1.4.1 ARM64 package installation and live providers remain separate acceptance evidence.
