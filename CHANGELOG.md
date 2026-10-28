# CHAT-R01–R03: plant-event validation explanations

Invalid plant-event submissions now explain the existing rejection beside the affected field. This patch does not change validation rules, transaction policy, stored data or the frozen historical specimen.

## Apply

1. Review/extract the 11 repository-relative files below into a clean source checkout (the directory containing OrchidApp.sln). Preserve any unrelated local edits. This is a source patch, not an installed application package.
2. Build the web application: `dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj --configuration Release`.
3. Commit/run the normal CI. Its existing lifecycle job now executes the new HTTP checks against generated upgraded and fresh schema-only fixtures. The full lifecycle command remains `pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1` with its existing explicit disposable-server credentials and prerequisites. Never point fixture checks at a collection server.
4. Package/deploy through the normal Windows installer or Linux publishing procedure. Preserve the normal backup/recovery route, including C18 app-only backups. On disposable records verify readable rejection messages and corrected save/reopen.

**No new database migration, .env change, startup setting or historical repair is required by this patch.** It does not replace the existing instructions for any other pending migrations.

## Every added/modified repository file

- **Modified `src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml`** — Render seven existing field-error positions for dates, missing repotting medium and empty observation notes; validation rules unchanged.
- **Modified `tests/LifecycleClosure.Checks/Database.Checks.ps1`** — Run the new HTTP regression suite for both generated upgraded and schema-only fixtures in the existing lifecycle job.
- **Modified `CONTRIBUTING.md`** — Document the lifecycle validation-message checks and isolated target requirement.
- **Modified `RELEASE_NOTES.md`** — Describe the UI correction, regression coverage and no-migration deployment impact.
- **Modified `docs/index.md`** — Link the validation-message owner/evidence.
- **Modified `docs/documentation-map.md`** — Identify the validation-message documentation owner.
- **Modified `docs/upgrade-checklist.md`** — Record Windows/Linux app-only deployment and disposable invalid/corrected-input acceptance; preserve C18 backup obligations.
- **Modified `docs/code-change-backlog.md`** — Track CHAT-R01–R03 as source implemented with local validation; leave merged CI/installed acceptance pending.
- **Modified `docs/testing-evidence.md`** — Include rendered field errors and corrected saves in lifecycle coverage.
- **Added `tests/LifecycleClosure.Checks/ValidationMessages.Checks.py`** — Add nine HTTP test methods covering rejection explanations, unchanged records, date binding and valid correction/save/reopen.
- **Added `docs/maintenance/event-validation-messages.md`** — Record problem, implementation, actual before/after tests, Word-guide impact review and remaining limits.

The root CHANGELOG.md is included only in this delivery ZIP; it is not an additional application change.

## Actual validation

- Current extracted review mirror, Windows AMD64, .NET SDK 9.0.315 targeting net8.0, MariaDB 10.11.16. Fresh private database data directories, generated canonical-schema databases and loopback-only hosts; no private .env or live/development database used.
- Pre-fix current build: nine test methods, 13 failing assertions/subtests reproduced missing errors; the valid-save method worked.
- Corrected build: all nine new HTTP test methods passed. Rendered messages are checked at the affected fields; rejected requests preserve records, and corrected requests save/reopen.
- All 16 existing ended-plant/date/read-only HTTP tests passed.
- Release build: zero warnings, zero errors. Python source compiled, lifecycle PowerShell parsed, existing CI workflow passed actionlint with optional ShellCheck/Pyflakes integrations disabled; changed Markdown local targets resolve.
- Windows 03 and Linux/Pi 02 plant-management Word guides reviewed: neither describes exact validation strings; controls and valid-state appearance are unchanged, so no Word/screenshot edits were required.

## Remaining limits

- The complete upgraded/fresh lifecycle matrix has not been rerun locally as a whole for this patch; the new suite and related existing policy suite were run directly against fresh canonical-schema fixtures. The existing CI runner is wired for both paths; retain its actual applied/merged-revision result.
- Git revision is unavailable for this extracted mirror. Merged-revision GitHub CI, Linux/current ARM64 execution, browser visual/JavaScript and installed-machine checks remain pending.
- The immutable old specimen is unchanged and continues to represent the historical behaviour. This patch does not implement C18 historical upgrades/recovery, Windows specimen creation, CI deduplication or other register items.
- No application repository files outside the listed set, synced sources, private settings, fixture data, binaries or whole-repository contents are packaged.
