# Windows installer backup and recovery

Every installer run over existing application or persistent files now requires a new verified offline recovery snapshot before replacing application files. This includes same-layout, app-only updates and repair/reinstall attempts; no pending SQL migration is needed to trigger the gate. A genuinely empty new installation needs no snapshot.

This policy belongs to C18. It supplements normal data backups and the existing Desktop migration/restore gates. It does not change development `dotnet run`, `.env` credentials, Linux backup configuration or database migrations.

## Before installing

1. Preserve a verified normal data backup and a separate off-computer recovery copy. Retain the previous trusted installer and note its version. The installer snapshot is local and cannot protect against loss of the computer or disk.
2. Close the browser and OrchidApp launcher. Stop all other writers, including separately run databases, backup scripts and imports. Keep them stopped until setup completes. Setup does not force-kill a process or database and no longer asks Windows to close applications automatically.
3. Run the trusted installer. Before copying its application payload, its embedded incoming helper checks process identities, links/reparse points and pending migration/restore/photo-recovery records. Unidentifiable OrchidApp/MariaDB processes stop the check even if they might be unrelated: obtain support rather than bypassing the guard. For a database that cannot stop cleanly, preserve its files and obtain support; a raw snapshot is not proof that its database is healthy.
4. Allow space for the previous app and current durable files in an additional compressed archive. The helper captures the selected old application root and ProgramData OrchidApp root. Each inventoried file is opened for read with writes/deletion denied throughout capture and verification. Every ZIP entry's length and SHA-256 is verified, and the source inventory/process/recovery checks are repeated before success. Failure stops installation before application replacement. A `.partial` file may remain as evidence; it is not an accepted backup.

On a standard machine the accepted archive is:

```text
C:\ProgramData\OrchidApp\backups\pre-install\OrchidAppUpgrade-<UTC-time>-<unique-id>.zip
```

The actual ProgramData location is resolved by Windows. The installer log records the verified snapshot path. Use Inno Setup's `/LOG` option when retaining detailed installation evidence. Recovery snapshots are never automatically pruned by this helper; review them manually after release acceptance and preserve required off-computer copies.

## What the snapshot contains

`installer-snapshot.json` identifies format version 1 and kind `OrchidAppOfflineInstallerRollback`. Its inventory maps `application/` to the selected old app root and `persistent/` to the matching ProgramData root. It includes the previous binaries/runtime, raw stopped database files, uploads, settings and state files that exist in those roots. It does not read development `.env` or start/alter a database. Existing top-level `backups/` trees under either root are excluded to prevent recursive capture; they remain in place and need their own preservation. Empty directories and Windows ACLs are not a machine-restoration image.

The archive is distinct from the logical SQL/upload ZIP accepted by **Restore from backup**. Do not select an `OrchidAppUpgrade-...zip` in that dialog. It needs offline support-assisted recovery with the matching prior database runtime and application. Never combine its old raw SQL files with new data files, or restore binaries alone after a schema-changing failure.

## If setup or the upgraded app fails

Keep the app and all other writers stopped. Preserve the snapshot, any earlier normal backup, failed application/data roots, installer log and migration/restore/photo-recovery records. A failed preflight leaves the old application and durable files unchanged apart from newly appended backup staging files. A later installer/runtime failure can have changed application files or SQL; the gate does not promise automatic rollback of either. Do not clear markers or repeatedly launch the failed installation to force it through.

The support operator can verify the snapshot without changing source data:

```powershell
pwsh ./app/tools/review-installer-snapshot.ps1 -Archive <absolute-snapshot-path>
```

From an installed package use `./tools/review-installer-snapshot.ps1` instead. For review/recovery, supply a new absent destination:

```powershell
pwsh ./app/tools/review-installer-snapshot.ps1 -Archive <absolute-snapshot-path> -ExtractTo <new-absolute-staging-directory>
```

The tool verifies every listed entry before extraction, refuses unsafe/duplicate/unlisted paths and an existing destination, checks extracted bytes, and never replaces the current application/database. Treat failed extraction staging as incomplete. No `-Force` overwrite mode is provided.

For an accepted offline rollback, the operator must first preserve the failed roots separately, verify the intended collection and recover the complete matching database/upload/settings state alongside the prior application/runtime into an isolated target. Reapply appropriate ownership/access; review migration ownership and installer registration/version rather than assuming staging reproduces a machine installation. Start only that isolated database with the matching runtime, verify identity/rows/photos/settings/history and readiness, then plan controlled activation. Never merge two MariaDB directories. Retain both recovery input and failed-state evidence until acceptance. Representative older-release and real-machine recovery remain release acceptance tasks.

## Release build and signing evidence

Repackage from source so all three snapshot tools are present. `scripts/build-windows-installer.ps1` rejects missing or stale packaged helpers and compiles the checked-in production identity. It writes `<installer>.evidence.json` with the actual produced file's SHA-256, version and Authenticode status. The repository has no automatic signing setup; a version/build does not establish a signed artifact. `-RequireValidSignature` fails if that actual artifact does not have a valid signature, retaining the file/report for review. It does not sign anything. Inspect again if the artifact is signed or modified later.

Source checks include actual Inno fixture installation/upgrade/uninstall with a randomly generated per-user identity, snapshot policy on both PowerShell versions, artifact evidence checks and an owned MariaDB recovery round trip. Fixture installers substitute only process enumeration; controlled policy rows test the production decision rules, including rejection of unidentified databases. These checks do not certify the administrator production installer against a representative older installed collection. See [C18 evidence](maintenance/c18-installer-upgrades.md) and the [Windows/Linux upgrade checklist](upgrade-checklist.md).
