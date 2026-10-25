# C05 CI database acceptance changes

Incremental changes-only delivery after C16 and the corrected C04 files. Contains 8 modified and 1 added repository files, plus this CHANGELOG.md. No enclosing repository directory, complete repository, runtime binaries, patch or database data is included.

## Apply

1. Extract directly over the repository root containing OrchidApp.sln, keeping the paths below and replacing existing files.
2. Review the file list and docs/maintenance/c05-ci-database-acceptance.md, then commit using the already configured development environment/hook. The C16 requirement for explicit MARIADB_DATABASE still applies.
3. Run GitHub Actions. Confirm the schema-only creation/upgrade step, canonical export/drift check and existing C04/C16 checks all pass.

No deletions or moves. No new production database migration is required. All 333 existing schema/checksum/historical migration files are unchanged. Real older-installation testing remains the separate future task agreed with the owner.

## Files

| Change | Repository path | Description |
| --- | --- | --- |
| Modified | `.github/workflows/ci.yml` | Replace independent schema loops with the production creator in a stage without migrations; include seeds/baseline, disposable upgrade checks and the C# baseline policy check; keep canonical drift separate. |
| Modified | `CONTRIBUTING.md` | Describe the new CI acceptance coverage and remaining limits. |
| Modified | `RELEASE_NOTES.md` | Record C05 behavior, agreed scope and evidence link. |
| Modified | `docs/code-change-backlog.md` | Record local implementation/validation, pending GitHub Actions and deferred older-installation scope. |
| Modified | `docs/database-creation.md` | Document the staged schema-only creation/upgrade suite and separate canonical CI drift workflow. |
| Modified | `docs/documentation-map.md` | Link the CI evidence from the authoritative database creation owner. |
| Modified | `docs/index.md` | Link the C05 CI acceptance evidence. |
| Added | `docs/maintenance/c05-ci-database-acceptance.md` | Record implementation, 44 database/18 C# checks, actual creation/export/drift validation and remaining acceptance. |
| Modified | `tests/SchemaBaseline.Checks/Database.Checks.ps1` | Stage actual production scripts without migrations, use structured child-process results and extend to 44 checks covering missing inputs/view order, baseline, seeds, record preservation and once-only future upgrade. |

## Validation actually performed

- All 44 expanded database creation/baseline checks passed locally on isolated Windows/MariaDB 10.11.16.
- All 18 C# baseline policy checks passed.
- The new CI creation block was extracted from the workflow and run in a disposable source stage containing production scripts/schema and no migration directory. Subsequent canonical export passed a Git index drift comparison with no differences.
- actionlint 1.7.7 validated the workflow; ShellCheck/Pyflakes integrations were disabled. The modified PowerShell suite parsed successfully. Changed Markdown file links and protected SQL/artifact hashes were checked.
- Generated test databases were dropped and the isolated test server was shut down. Small unique fixture directories were retained outside this ZIP for diagnosis. No live database was used.

## Limits and next step

The updated GitHub Actions/Linux run has not been executed here and still needs confirmation. Current-schema creation followed by a synthetic later migration is covered; a real historical installation/backup is not. The existing synthetic legacy-history checks test bookkeeping only. C16 native/platform CI acceptance, device/installer, real backup recovery and broad feature-test coverage remain separate. No web-app rebuild was needed for this CI/test/docs-only change; the affected C# policy project and real MariaDB workflow were run instead.

After C05 review/CI confirmation, continue with C06+C07: legacy safety backup source selection and settings restore compatibility.
