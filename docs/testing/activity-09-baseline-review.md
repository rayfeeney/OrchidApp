# Activity 09 baseline review

Review evidence captured on 28 November 2026 under the [programme](automated-testing-mariadb118-plan.md) and its [detailed criteria](activity-05-review.md). The owner approved Activity 09 and Gate 1 on 28 November 2026. The owner accepted the known Windows v1.4.1 backup limitation on 28 November 2026.

## Retained inputs and environments

All four inputs were downloaded from their release locations, checked locally with SHA-256, and retained under the ignored `dist/activity09-baseline-assets/` directory. Run reports remain in the local evidence directories identified below.

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| `OrchidAppSetup-1.4.1.exe` | 149,514,313 | `4b116a69c37ef214215efd3fe5655cfece02f5e6d026346f9ab45ddd1ebdba4e` |
| `OrchidApp-v1.4.1-RaspberryPi-Linux-arm64.zip` | 75,676,945 | `c1524ee5cb2985972565d00d6bfa834a140cd0e06ae6b425dcf183a4548aac19` |
| `OrchidApp-v1.4.0-Sanitised-Specimen.zip` | 10,065,174 | `18a10fb72501cf412c3bc8a599dbc693069497665b59c00945f3740a11375786` |
| `OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz` | 94,612,484 | `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5` |

The [published v1.4.1 release](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.4.1) points to `5dc488812872b60e8655a67b5ef4676347b5e47a`. The published Windows test used Windows 11 build 26100 x64 and bundled MariaDB 10.11.16. The separate passing Windows candidate used source `0b66cd4851fcf19d26ba47739e3c2503cbaf33ef` and the same MariaDB series and guest build. See the [Windows harness evidence](../../tests/WindowsSandbox.Checks/README.md).

The installed Linux source fixture used Debian 12.15 x64, MariaDB 10.11.19, .NET 8 SDK 8.0.428 and real systemd. The published Linux package ran under Docker ARM64 emulation with an isolated amd64 MariaDB 10.11.14 server and private local rclone crypt storage. A distinct local build with SHA-256 `d9344bb7ba0594665150788e525ce6a88eb71af95bfde384a0c8a82f53dc2a24` supplied the app-only replacement phase. See the [Linux harness evidence](../../tests/LinuxAcceptance.Checks/README.md).

## T01–T16 evidence

| ID | Windows | Linux |
| --- | --- | --- |
| T01 Installation and deployment | Published installer passed in Sandbox. | Installed x64 source deployment and published ARM64 upgrade deployment passed in their respective environments. Physical Pi installation remains unverified. |
| T02 Startup and readiness | Published application reached readiness. | Published ARM64 application and installed x64 service passed readiness. |
| T03 Database provisioning | Published fresh database reached readiness. Candidate browser writes and schema-contract CI provide separate evidence. | Installed x64 canonical schema-only creation passed, with a baseline-only ledger and browser writes. |
| T04 Migrations | Candidate historical install passed its migration and recovery-snapshot stage. Use the isolated CI checks for deliberate failure and retry coverage. Published upgrade remains unverified. | Published ARM64 run applied four forward migrations, preserved 245 ledger rows and confirmed a no-op repeat. The isolated harness exercised partial-DDL failure and refused retry. |
| T05 Specimen restore | Exact specimen passed offline historical restore and candidate launcher restore. Published v1.4.1 launcher restore remains unverified. | Frozen specimen passed inventory and schema checks and reopened in the isolated historical workflow. Four missing inactive photo references are expected. |
| T06 Core workflows | Candidate shared browser plant and validation checks passed. | Installed x64 shared browser checks and published ARM64 plant actions passed. |
| T07 Photo upload and processing | Candidate large JPEG and HEIC, originals and thumbnails passed. | Installed x64 large JPEG and HEIC, originals and thumbnails passed. The published ARM64 harness verified existing media and plant actions. |
| T08 Backup creation and validation | Published startup backup hit the accepted archive-module failure. Candidate managed backup and archive validation passed. | Installed x64 and published ARM64 paired capture and encrypted local read-back passed. |
| T09 Backup restore and integrity | Candidate launcher round-trip and fresh-target restore passed, including restart, photos and settings. Published round-trip remains unverified. | Installed x64 isolated restore passed record, media, configuration, readiness and browser reopen checks. Published ARM64 paired recovery also passed. |
| T10 Shutdown and restart | Candidate launcher shutdown and reopen passed. Published startup passed, with the complete lifecycle unverified in that run. | Installed x64 real systemd stop/start and browser reopen passed. Published ARM64 restart persistence passed under emulation. |
| T11 Launcher | Published launcher opened the app and reproduced the startup backup defect. Candidate Open, Close, Backup and Restore passed. Live OneDrive remains unverified. | Outside Linux scope. |
| T12 Uninstall | Candidate uninstall and persistent-file preservation passed. Published uninstall remains unverified in the baseline run. | Outside Linux scope. |
| T13 systemd services | Outside Windows scope. | Debian 12 x64 real systemd registration, service identity, stop, restart and readiness passed. |
| T14 Environment importer | Outside Windows scope. | Debian 12 opt-in fixture passed stored-row, replay and service/timer wiring checks using local CSV. Live IMAP remains unverified. |
| T15 Nightly backup and standby recovery | Outside Windows scope. | Debian 12 timers passed encrypted publication and standby preparation. All 122 policy checks passed. Separate CI exercised isolated 10.11-to-11.8 data restore. Full installed standby acceptance, live provider reporting and retention remain outside the Debian 12 result. |
| T16 Application and database upgrade | Published v1.4.0 to unpublished candidate passed installation, recovery snapshot, app startup and media verification. The historical harness stopped later at the backup dialog; the clean candidate run passed corrected handling. Published v1.4.1 upgrade remains unverified. | Exact published ARM64 package passed historical application upgrade and recovery under emulation. The planned engine upgrade remains assigned to Activity 12. |

## Evidence and decision

- Windows published rerun `dist/activity09-windows-sandbox/20261128T113042Z-6827f608/evidence/report.json`. The automatic backup failed because PowerShell could not find the `en-GB` archive resource `ArchiveResources.psd1`. Retest backup, specimen restore and backup round-trip in a fresh Sandbox on the next published version containing the fix.
- Published Linux report `dist/activity09-linux-evidence/20261128T114008Z-9f3a44ca/report.json` and `application/application-report.json` under the same run directory.
- [Historical ARM64 CI](https://github.com/rayfeeney/OrchidApp/actions/runs/46136490543) and [Activity 08 merge CI](https://github.com/rayfeeney/OrchidApp/actions/runs/46138574117).
- The owner approved these baselines with the documented limitations after PR #405 merged and all eight post-merge CI jobs passed. [Merge CI](https://github.com/rayfeeney/OrchidApp/actions/runs/46142587657)
