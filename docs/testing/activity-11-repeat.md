# Activity 11 automated test repeat

The repeat on 28 November 2026 used candidate commit
`72bc337fc8df682e846e82624e3c02f3fd852d78` from [PR #407](https://github.com/rayfeeney/OrchidApp/pull/407).
All eight [GitHub Actions jobs](https://github.com/rayfeeney/OrchidApp/actions/runs/46169679794)
passed on that exact revision. The Windows job retained the build identity
and signature status. The installed Windows and Linux exercises below
used separately built artifacts from the same source revision.

| Check | Observed result |
| --- | --- |
| Windows clean install and launcher | Windows 11 build 26100 x64, MariaDB 11.8.9, schema provisioning, readiness and automatic backup passed. The launcher restored the approved v1.4.0 specimen, passed shared browser writes and large JPEG/HEIC checks, and passed the managed backup, restart and round-trip checks. Uninstall preserved durable files. |
| Windows separate restore | A second clean Sandbox installed the same candidate, restored the exact retained backup and reopened the witness plant and photos after restart. Media and settings matched the source. |
| Linux install and browser | Debian 13.8 x64, MariaDB 11.8.9, locked .NET 8 Release build, canonical schema and seeds and full readiness passed. The separately named Activity 11 service passed actual systemd stop/start, shared Chromium writes and large JPEG/HEIC checks. Chromium reopened the same plant, photos and thumbnails after another restart. |
| Linux paired recovery | The source backup passed encrypted local read-back. Records, four media files and one configuration file matched in a separate socket-only 11.8.9 database. The recovered app ran with copied state and a fresh fixture configuration and passed readiness and browser reopen. |
| Linux importer | Connector/Python 1.1.15 on Python 3.13. Two local CSV imports kept identical reading IDs and values, with two completed audit entries and one input hash. The systemd timer targeted the importer and was stopped after the check. |
| Linux scheduled backup and standby data | Timed backup and preparation passed. The first standby data stage failed with MariaDB 1449 for the missing locked fixture definer and retained its failure state. A fresh scheduled retry used the same snapshot and only the two known locked fixture identities. Both schemas restored with 24 inventoried base tables each and verified photo references. The candidate stopped at `DATA_RESTORED_APPLICATION_PENDING`. Both source services were active afterward. |

Windows installer SHA-256
`cfea7e721d239a10f4d16246163da9f81748d9bd4342cfa485146f0bd4876fa5`.
The unpublished, unsigned artifact identifies itself as
`1.4.0+build.11.72bc337fc8df682e846e82624e3c02f3fd852d78`.
Windows backup SHA-256
`5da8820f00c5dd43350fdb10bfa71e94bec6c8d699b64625fee954b715b5ee04`.

Linux paired snapshot SHA-256
`1ab7a2e9ecc56bdef54d420ee86d3f33f9bc5c45bf9c99a75c40003b53a3cc6b`.
Scheduled snapshot
`orchidset-20261128T182932Z-e2ae48fad9554c1a94686f6a5f17a28d`,
SHA-256 `544e98516f2ef72c0208a4954d33581985206d579115f9bdeb35ee74fceaeadf`.

## Evidence locations

- CI artifacts under `dist/activity11-ci-46169679794/`.
- Candidate installer identity and Sandbox reports under `dist/activity11-windows-evidence/`, source run `20261128T173359Z-3be25f71` and separate restore `20261128T180657Z-58fcd1bc`.
- Debian 13 deployment, browser, restart, backup, recovery, importer and timer logs under `dist/activity11-target-*.log`. The locally retained recovery and timer scripts identify the exact disposable fixtures and snapshot.
- The [Linux test harness](../../tests/LinuxAcceptance.Checks/README.md) documents the repeat profile. It keeps the known Activity 10 source fixture available and gives Activity 11 separate paths, database and service.

Live OneDrive, IMAP and SMTP were outside these fixture runs. The scheduled
restore used the two disposable application and importer schemas. Full
standby application acceptance remains separate. Existing-installation
10.11-to-11.8 upgrade and recovery acceptance belongs to Activity 12.
The owner reviewed and merged PR #409. All eight post-merge CI jobs passed. Gate 2 remains pending. [Post-merge CI](https://github.com/rayfeeney/OrchidApp/actions/runs/46188137528)
