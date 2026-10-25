# C16 developer setup changes

This is an incremental changes-only delivery on top of the previously applied C01/C02, C03 and corrected C04 deliveries. It contains 16 modified and 7 added repository files, plus this manifest. No enclosing repository directory, patch file, runtime binaries or live data is included.

## Apply

1. Keep your normal backup/source-control copy of the repository.
2. Extract the ZIP directly over the repository root containing OrchidApp.sln, retaining the paths below and replacing existing files.
3. Read docs/development-setup.md. The shared Development settings no longer supply a password, endpoint or upload path: supply all five MARIADB values and an absolute Storage__UploadRoot, then dot-source scripts/DevSetup/configure.ps1 in the terminal used for app/scripts/Git.
4. Use setup.ps1, schema-only creation where appropriate, and run.ps1 as documented. The exporter now also requires MARIADB_DATABASE explicitly. Existing custom CI/environment users must supply it.
5. Run CI. The added native/configuration checks on Windows and Ubuntu still need confirmation for this delivery.

No files are deleted or moved. No database migration is required for these tooling/configuration changes. All 333 existing schema, checksum and historical migration files were verified unchanged. The configuration change intentionally removes committed machine credentials; preserve legitimate private overrides outside source control.

## Files

| Change | Repository path | Description |
| --- | --- | --- |
| Modified | `.github/workflows/ci.yml` | Add Windows/Linux development configuration and native photo checks; make export database explicit. |
| Modified | `.gitignore` | Ignore locally restored app/runtime inputs. |
| Modified | `CONTRIBUTING.md` | Add development checks and distinguish confirmed C04 CI from pending C16 CI. |
| Modified | `RELEASE_NOTES.md` | Describe C16 behavior and link instructions/evidence. |
| Added | `database/scripts/Database-Environment.ps1` | Require and validate the explicit five-value MARIADB endpoint. |
| Modified | `database/scripts/Export-MariaDBSchema.ps1` | Remove endpoint/alias fallbacks, ignore native option files, use TCP/UTF-8, fix dump argument collision and restore MYSQL_PWD. |
| Modified | `docs/architecture.md` | Describe source-run configuration/native preflight and remaining Production readiness scope. |
| Modified | `docs/code-change-backlog.md` | Record actual C04 confirmation and C16 local implementation/pending acceptance. |
| Modified | `docs/database-creation.md` | Document the explicit schema export endpoint contract. |
| Modified | `docs/development-setup.md` | Replace obsolete setup instructions with one reproducible configuration, creation, native/source-run and hook procedure. |
| Modified | `docs/documentation-map.md` | Link C16 evidence from the developer setup owner. |
| Modified | `docs/index.md` | Link C16 evidence and remaining acceptance. |
| Modified | `docs/maintenance/c04-migration-runners.md` | Append the owner-reported successful corrected CI result. |
| Added | `docs/maintenance/c16-developer-setup.md` | Record implementation, actual local tests and remaining CI/fresh-platform acceptance. |
| Modified | `scripts/DevSetup/ci-local.ps1` | Replace obsolete MySQL Docker route with existing disposable MariaDB suites. |
| Added | `scripts/DevSetup/configure.ps1` | Generate the app connection string from the script endpoint; validate uploads and set Development/monitoring/charset. |
| Added | `scripts/DevSetup/run.ps1` | Restore Windows native runtime, probe actual photo processing and start the source app; support CheckOnly and a separate URL. |
| Modified | `scripts/DevSetup/setup.ps1` | Check supported .NET/MariaDB tools/server and activate hooks without MYSQL aliases or DB object writes. |
| Modified | `scripts/restore-windows-runtime.ps1` | Add LibVipsOnly, pinned archive checksum, required DLL/version checks and removal-target containment validation. |
| Modified | `src/OrchidApp.Web/appsettings.Development.json` | Remove committed password, machine database endpoint and personal upload directory. |
| Added | `tests/DevelopmentNative.Checks/DevelopmentNative.Checks.csproj` | Compile the real photo pipeline into a standalone native smoke check with the existing NetVips version. |
| Added | `tests/DevelopmentNative.Checks/Program.cs` | Save, fully decode and validate separate photo/thumbnail JPEGs in an isolated probe directory. |
| Added | `tests/DevelopmentSetup.Checks/Configuration.Checks.ps1` | Add 17 endpoint, quoting, required-value and upload-path checks with environment restoration. |

## Validation actually performed

- 17 development configuration checks and 8 MariaDB tool resolution checks passed.
- Full Windows libvips 8.18.2 runtime downloaded; native photo/thumbnail save, full decode and dimension checks passed, including a clean native-check output build using the full runtime PATH.
- Setup connected to MariaDB 10.11.16 and activated hooks in a disposable Git checkout. Schema-only creation with seeds/baseline and the actual pre-commit export/staging hook passed. The final explicit UTF-8 exporter was rerun through that hook successfully.
- The source app started through the new wrapper on a separate loopback port. Home, Plants and Photos returned HTTP 200. A generated PNG was uploaded with antiforgery validation; the photo page reopened; separate photo and thumbnail JPEGs were fetched over HTTP and matched stored bytes.
- All 53 migration database checks plus 10 child-process protocol checks passed after the endpoint/dump argument correction.
- Release web build: zero warnings/errors. Changed PowerShell syntax, Markdown file links and JSON parsing passed. The source mirror has no Git metadata, so no source git diff check or commit was claimed; the real hook ran only in the disposable checkout.
- Test databases/services created for this resumed run were cleaned up. No live collection was used.

## Remaining checks and limits

New GitHub Actions steps have not been run here. Linux system-libvips/source HTTP validation, a completely fresh Windows/Linux OS, Pi hardware, installer and recovery acceptance remain pending. Local tests used installed SDK 9.0.315 with .NET/ASP.NET 8 runtimes and MariaDB 10.11.16. Native-project restore reported NU1900 when online vulnerability metadata was unavailable; native build/check passed, but no successful online audit is claimed. Production readiness work remains C19. C05 is next in the agreed order after reviewing this C16 delivery/CI result.
