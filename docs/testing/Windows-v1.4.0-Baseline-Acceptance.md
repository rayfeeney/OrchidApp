# Windows v1.4.0 baseline acceptance

**Status as of 6 November 2026: baseline complete (item 13).** The owner confirmed a successful clean installation from the GitHub release installer. That installation was restarted and checked and provided the sanitised specimen. The bundled restore script succeeded on a separate machine, and the restored collection remained available after restart. Launcher backup and restore failures and large JPG and HEIC upload issues remain open for resolution. Earlier Windows upgrade paths are outside this baseline's scope.

## Release identity

The local Git tag `v1.4.0` resolves to commit `7dae518cf3e8a8b82a453119413e58dfa84fdd14`. Both installed OrchidApp executables report product version `1.4.0+build.0.7dae518cf3e8a8b82a453119413e58dfa84fdd14`. The hashes below were checked against the local installer and the binaries under `C:\Program Files\OrchidApp`. Authenticode reported `NotSigned` for all three.

| File | SHA-256 |
| --- | --- |
| `OrchidAppSetup-1.4.0.exe` | `B271D9B1DA0C351B28736A660C2952C10E14ACB3C716DA0E048C57D83D26B318` |
| `OrchidApp.Launcher.exe` | `4EB6CEE7BC1AD1BD8E200D960D3D76D783FD36CCA751B94FBB4D457FE5FB8787` |
| `OrchidApp.Web.exe` | `6F46114CE188A5C50DF0A62E4664ADD1EA13E7EFBD634868D807C5E3A6570FB8` |

## Backup and specimen evidence

| Check | Result |
| --- | --- |
| Clean installation | The owner confirmed that the installation used to create the specimen was a clean install from `OrchidAppSetup-1.4.0.exe` on the GitHub v1.4.0 release page. The Windows version and Smart App Control setting for that run were not recorded in this evidence. |
| Backup capture | The baseline exercise produced `OrchidAppBackup_20261105_211234_599_9d0b6fda.zip`. Its format-2 manifest identifies it as a normal backup. The local archive contains the SQL export and schema-version file and records 20 upload files. The listener-detection failure below still applies to the normal launcher path. |
| Sanitised specimen | `OrchidApp-v1.4.0-Sanitised-Specimen.zip`, 10,065,174 bytes. Local SHA-256 is `18A10FB72501CF412C3BC8A599DBC693069497665B59C00945F3740A11375786`. The archive contains the database export, schema-version file, launcher settings, and 20 photo and thumbnail files combined. |
| Specimen validation | The baseline exercise recorded a pass for manifest validation. The personal OneDrive backup path was cleared. The final manifest checks found no Windows username, OneDrive reference or Windows user-profile path. This evidence covers archive integrity and the recorded sanitisation checks. |
| Release preservation | The owner confirmed that the installer was already attached and that the sanitised specimen was uploaded alongside it as a test fixture. The specimen downloaded on the second Windows machine matched the recorded SHA-256. [GitHub release](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.4.0) |
| Restart and functional check | Passed on the existing v1.4.0 installation during the baseline exercise. This was an application restart and functional check against the existing collection. |

## Known Windows issues

- **Smart App Control.** Windows Smart App Control can block the unsigned v1.4.0 installer or executables. Signing and launch under the target Windows security policy remain part of installer acceptance.
- **Large JPG and HEIC uploads.** Large JPG uploads can fail with `VipsJpeg: out of order read` during EXIF orientation handling. The failure was reproduced separately with generated 5120 × 3840 JPEGs. HEIC upload was also reported as a problem. Its cause and behaviour on a clean installation remain unverified. Retest the formats separately against a candidate Windows package. [Photo handling](../photo-handling.md)
- **Backup listener detection.** With the launcher-owned MariaDB already reachable at `127.0.0.1:3308`, Windows listener enumeration returned no listener. The backup script tried to start a second server against the same data directory. MariaDB failed on `ibdata1`, and the cleanup error surfaced as an abnormal exit before cloud copy. A direct TCP query reached the existing server and confirmed its data directory. The preserved backup establishes capture for the specimen exercise. Launcher-driven backup with the database already running and cloud-copy verification still need acceptance. [Windows backup format](../windows-backup-format.md)

## Independent restore attempt

On 6 November 2026, the owner selected the checksum-verified specimen ZIP in the launcher on a second machine with a clean v1.4.0 installation. The launcher stopped the web app. The restore then failed while creating the mandatory safety backup of the target collection. The script reported `MariaDB exited abnormally; do not copy its raw files` and exited with code 1. It retained a copy as `recovery-input.zip` under the target's `restore-recovery` directory and reported that no restore SQL had started. The database and upload replacement stages were not reached.

The failure is consistent with the known MariaDB listener-detection defect. The launcher log alone does not establish why MariaDB exited on the second machine.

Later that evening, the owner closed OrchidApp on the second machine and confirmed that the MariaDB port was no longer reachable. Running the bundled v1.4.0 `restore-orchidapp.ps1` directly against the same specimen succeeded. The script created and retained the mandatory safety backup, retained a copy of the input ZIP, and reported that the database, referenced photos and settings were verified. This result applies to the offline script path. The launcher path failed in the earlier attempt.

After opening OrchidApp on the second machine, the owner reported that the application was working and the restored data matched expectations. The owner then confirmed that the restored records, full-size photos and thumbnails remained available after restarting OrchidApp.

## Open defects and retests

- [ ] **Launcher backup and restore.** Resolve the failures in both launcher workflows. On an isolated Windows installation, verify that Back up now creates a valid archive while the launcher-managed database is running and completes cloud copy when configured. Verify that Restore creates its mandatory safety backup, restores the database and photos, and leaves the restored collection available after restarting OrchidApp.
- [ ] **Photo uploads.** Resolve the large JPG and HEIC upload issues. Retest each format separately from the app in a candidate Windows package and check that both the full-size photo and thumbnail display.

See the [upgrade checklist](../upgrade-checklist.md) and [current work list](../current-state.md) for release acceptance tracking.
