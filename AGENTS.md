# OrchidApp repository instructions

## Working rules

Read [docs/index.md](docs/index.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before changing behaviour. Use [docs/documentation-map.md](docs/documentation-map.md) to identify the authoritative document for each area. Put new explanations, change summaries and reports under docs/, not at repository root. Keep required root files such as this file, README.md, CONTRIBUTING.md, RELEASE_NOTES.md and licence notices in their established locations.

## Development governance

- Carry out all application, database, script, configuration and documentation development on the designated Windows DEV PC.
- Treat Raspberry Pis as operational and deployment environments, not development environments.
- GitHub is the authoritative source for application code, database definitions, scripts, configuration templates, tests, documentation and development decisions.
- Do not make untracked or ad hoc changes to deployed application code or repository-controlled configuration.
- Distinguish read-only operational inspection from actions that modify an operational environment. Obtain owner approval before modifying live environments.
- Check the current branch, working tree and relevant repository status before starting work.
- Start new work from the latest appropriate origin/main using a dedicated scoped branch.
- Preserve unrelated uncommitted changes and existing branches. Do not discard, stash, overwrite or delete unrelated owner changes without approval.
- Submit changes through pull requests rather than committing directly to main.
- Review applicable local validation and CI results before merging. Verify applicable post-merge CI results.
- Review the finished commit and return the development checkout to an appropriate state after completing work.
- Do not introduce paid services, licences, subscriptions or infrastructure without explicit owner approval.

## Architectural consistency and implementation reuse

Maintain OrchidApp as a coherent application. Every change must be implemented in the context of the whole application, not merely the immediate requirement.

Before designing or implementing a change:

- Inspect existing implementations of the same or similar functionality across the repository.
- Identify applicable architectural contracts, shared components, services, utilities, scripts and tests.
- Establish the authoritative implementation pattern before introducing changes.
- Follow established naming conventions, coding patterns and architectural boundaries.
- Determine whether the requirement applies to Windows, Linux or both platforms.
- Identify affected documentation and existing acceptance criteria.

When implementing changes:

- Maintain a single authoritative implementation of shared functionality wherever practical.
- Prefer extending an appropriate existing component over creating a parallel implementation.
- Avoid unnecessary duplication of business logic, validation, database access, configuration, operational mechanisms and tests.
- Keep platform-specific implementations limited to genuine platform requirements.
- Apply consistent approaches to error handling, logging, resource management, configuration, validation and testing.
- Use existing application services, shared Razor components, database access mechanisms, utilities and test infrastructure wherever appropriate.
- Do not introduce alternative implementations merely because they are easier to develop in isolation.
- Do not introduce new frameworks, dependencies, architectural patterns or abstractions without a demonstrated requirement and explicit owner approval.
- Do not introduce speculative abstractions solely in anticipation of possible future requirements.

Where multiple implementations of similar functionality already exist:

- Determine whether the differences are intentional, necessary or historical.
- Review the applicable architectural contracts before selecting an implementation as authoritative.
- Record material inconsistencies and their implications.
- Obtain owner approval before undertaking consolidation or unrelated refactoring.
- Do not introduce a further implementation without explicit justification and owner approval.

Where an established implementation pattern is unsuitable, explain its limitations, identify the affected components and obtain owner approval before departing from it.

Update the authoritative architecture or technical documentation whenever an approved change establishes or modifies a shared implementation pattern.

## Scope and change control

- Work within the explicitly agreed requirements and completion criteria.
- Do not expand the scope of an activity without owner approval.
- Do not introduce unrelated functionality, improvements or refactoring simply because an opportunity is identified.
- Review and reuse existing functionality, scripts, tests and documentation before creating replacements.
- Record unrelated defects, inconsistencies and improvement opportunities as GitHub issues rather than diverting the current activity.
- Investigate blockers only sufficiently to determine their impact on the agreed work.
- Do not reopen completed work without new evidence.
- Maintain agreed work lists and programme references without silently adding, removing, renumbering or redefining activities.
- Escalate material architectural decisions, scope changes and unresolved blockers to the owner.

## Pre-implementation review

Before implementing new functionality or a significant change, establish:

- Which existing implementations of similar functionality have been reviewed.
- Which authoritative architectural pattern applies.
- Which existing components, services, scripts and tests can be reused.
- Whether unnecessary Windows and Linux differences have been avoided.
- Whether the proposed change remains within the agreed scope.
- Whether departures from established patterns require owner approval.
- Which authoritative documents and acceptance checks are affected.

Do not proceed with an unresolved material architectural or scope decision.

## Testing integrity and regression control

- Establish an appropriate verified baseline before significant architectural, dependency, database or packaging changes.
- Repeat applicable baseline tests following implementation.
- Preserve original specimen backups, recorded checksums and expected contents.
- Perform destructive testing only against designated disposable environments and working copies of specimen data.
- Never perform destructive testing against live operational databases or collections.
- Reuse existing test fixtures, assertions and automation wherever appropriate.
- Distinguish development checks, CI results, packaged-release acceptance and operational acceptance.
- Do not report a test as passed unless it has actually been executed successfully.
- Do not weaken acceptance criteria or remove meaningful assertions merely to obtain a passing result.
- Record actual results, failures, limitations and outstanding acceptance requirements.

## Release and deployment governance

- Obtain owner approval for the release version and release creation.
- Validate the actual release artifacts, not merely the source or development build.
- Preserve relevant artifact identities, checksums, version information and acceptance evidence.
- Verify affected installation, upgrade, backup, restoration and recovery procedures.
- Do not publish a release or deploy it to an operational environment without explicit owner approval.
- Follow the documented platform-specific deployment and recovery procedures.

## Working with the project owner

- Provide implementation and troubleshooting instructions one step at a time.
- Wait for the result before issuing dependent instructions.
- Prefer single-line PowerShell commands where practical.
- Clearly distinguish read-only, modifying and destructive commands.
- Use existing configuration and credentials without unnecessarily requesting them again.
- Do not assume that a command, build, test, commit, pull request or deployment has completed successfully.
- Explain material decisions, assumptions, deviations, blockers and validation limitations.
- Maintain sufficient repository documentation for another developer to continue the work without relying on conversation history.

## Build and dependency policy

- Use the .NET 8 SDK and runtimes. Keep the web app, Windows launcher and executable checks on .NET 8, including the EF Core and Pomelo stack. Review resolved dependencies when changing packages, regenerate the web NuGet lockfile and verify it with `dotnet restore src/OrchidApp.Web --locked-mode`. Check third-party notices for dependency and distribution changes.
- Run commands from the repository root. Use a scoped branch and review the diff, staged changes and finished commit. Use the required pre-commit hook on every commit. It exports and stages schema/checksums from the isolated development database and aborts on failure. Review generated changes for unrelated database drift. Never bypass the hook with `--no-verify`.
- Treat [developer setup](docs/development-setup.md), the [contribution checks](CONTRIBUTING.md), the [testing inventory](docs/testing-evidence.md) and the current owners in the documentation map as the detailed procedures. Preserve earlier validation records as historical evidence.

## Data, architecture and validation

- Use MariaDB and isolated development or disposable fixture data. Validate affected SQL behaviour, case and collation on Linux and affected packaging on Windows. Keep general installs independent of bespoke monitoring and leave `Monitoring:Enabled` false for general use. Follow the [monitoring activation boundary](docs/environment-summary-platform.md).
- Back up an existing, correctly baselined database before applying new migrations. Add a uniquely ordered timestamped migration through the [canonical runner contract](docs/migration-runners.md). Preserve incomplete markers and follow documented recovery after partial DDL failure. Apply reviewed migrations before exporting. Never edit generated schema or checksum files manually.
- Follow [architecture](docs/architecture.md) and [temporal rules](docs/temporal-design.md). Use the intended stored procedures for structural lifecycle writes, established EF Core patterns for other writes, async database I/O, parameters and trusted procedure identifiers. Use the shared stored-procedure executor where appropriate. Preserve calendar-date and timestamp distinctions, same-day ordering and ended-plant rules. Surface operational failures.
- Reuse shared Razor components, preserve validated local return destinations across GET, POST, errors, Cancel and successful saves, and follow [navigation](docs/navigation.md), [rich notes](docs/rich-notes.md) and [photo handling](docs/photo-handling.md). Check affected mobile workflows. Update labels and screenshot references together.
- Run affected executable checks and CI. Keep isolated feature checks separate from opt-in greenhouse SQL suites. Use only designated disposable targets for database, migration failure, restore and installer exercises. Keep package database cleanup isolated from deployed databases. Follow the [Windows upgrade](docs/windows-upgrade-contract.md), [installer recovery](docs/windows-installer-recovery.md) and [Linux upgrade](docs/user-guides/linux/installation-upgrade.md) contracts. Verify actual package, records, photos, settings, restart and recovery on isolated supported targets. Retain signing evidence and the exact release and machine acceptance record.
- Keep shared Word guide content aligned across platforms. Preserve useful screenshots, check their relevance and render and inspect all pages. Maintain the Word originals and preserve historic release PDFs.

## Development credentials

The repository-root `.env` holds this development checkout's database credentials. Do not ask the owner to re-enter credentials already held there, and never print, commit or package the private file or its values. Development database update and pre-commit export wrappers read the five MARIADB connection values from this file as literal data; they do not execute it or rely on a Git GUI inheriting terminal credentials. Use `pwsh ./scripts/DevSetup/update-database.ps1` to back up and apply pending development migrations, with the development app stopped. Do not run it against a collection/production database. Production/Desktop and operational deployment scripts retain their separate explicit configuration contracts.

## Documentation is part of every code change

Maintain docs/upgrade-checklist.md with every C01–C20 implementation or deployment-affecting change. Update its Windows/Linux actions and issue coverage together; record new settings, exact migrations, one-time actions, recurring verification and recovery implications. Keep unfinished requirements explicitly pending. Release preparation must produce a release-specific checklist and acceptance record; source/CI success alone does not certify an installed upgrade.

- For each code, SQL, script, configuration, dependency, packaging or UI change, review the affected current guides and update them in the same change. Check this even when the code change appears small.
- Check referenced files, links, commands, setting names/defaults and platform scope against the implementation. Record what was actually validated. Do not claim a build proves install, database, device or recovery behaviour.
- Keep general installation independent of the owner's bespoke monitoring installation. New databases must be created from database/schema/ and its required reference seeds alone; never create one by replaying database/migrations/. Migrations apply only to changes after creation. Keep baseline metadata compatible without requiring historical migration SQL for creation.
- Record new implementation/documentation mismatches and remaining acceptance in [docs/current-state.md](docs/current-state.md), with affected files, status and acceptance checks. The [completed C01–C20 backlog](docs/history/code-change-backlog.md) preserves historical evidence. Do not write pending behaviour as already implemented.
- If a document under docs/ becomes inapplicable or superseded, move it to docs/history/, preserve its context and identify the replacement. Update incoming current links and the documentation index/map. Preserve original historical evidence and licence texts.
- Before marking work complete, state which documentation was updated, or give a specific reason none was affected. Run appropriate link/command checks and relevant workflow validation. For Word edits, render and inspect all pages, preserving useful screenshots and checking their relevance; identify any device testing still pending.
- Keep backlog status aligned with actual validation. Database fixes require new migrations for existing databases and regenerated schema/checksum artefacts; never edit applied migration history or generated schema directly.

## Create a clean source review ZIP

Run from the repository root in PowerShell. This includes uncommitted source and documentation, not live collection data. Review retained files for secrets before sharing.

```powershell
$archivePath = Join-Path $env:USERPROFILE 'Downloads\OrchidApp-clean.zip'
tar.exe -a -c -f $archivePath --exclude=.git --exclude=bin --exclude=obj --exclude=./dist --exclude=./.runtime-downloads --exclude=./app/runtime --exclude=./app/data --exclude=./app/backups --exclude=./state --exclude=./infrastructure/environment-importer/downloads --exclude=./src/OrchidApp.Web/wwwroot/uploads --exclude=.vs --exclude=.idea --exclude=node_modules --exclude=__pycache__ --exclude=.venv --exclude=.env --exclude='.env.*' --exclude=appsettings.Production.json --exclude='appsettings.*.Local.json' --exclude=launcher-settings.json --exclude='*.csproj.user' --exclude='*.csproj.lscache' --exclude='*.log' .
if ($LASTEXITCODE -ne 0) { throw 'Archive creation failed.' }
```

Only the root dist is excluded; nested vendored web-library dist folders are required. The broad .env.* exclusion also omits .env.example from the ZIP. This is not a full backup or a guarantee that other files contain no secrets. See the [database creation contract](docs/database-creation.md) and [current work list](docs/current-state.md) for remaining release and operational work.

Keep the installed Raspberry Pi/Linux process in the [Linux user guide](docs/user-guides/linux/installation-upgrade.md). Link other operator documents to it. The sequence is stop writers, verify backups, fetch the approved release, apply pending migrations, publish and deploy, then start and verify.

## Automated testing and MariaDB 11.8 programme

Follow the [controlled programme of work](docs/testing/automated-testing-mariadb118-plan.md) when undertaking automated testing, MariaDB 11.8 re-engineering and associated release acceptance.

- Read the programme before commencing any related work.
- Identify the current numbered activity and its completion criteria.
- Complete one activity at a time and respect the owner approval gates.
- Do not expand, renumber or redefine the agreed scope without explicit owner approval.
- Review and reuse existing tests, specimen backups and validation evidence before creating replacements.
- Record unrelated findings as GitHub issues rather than diverting the current activity.
- Investigate blockers only sufficiently to determine their impact on the current activity.
- Update programme status using actual validation evidence.
- Do not commence MariaDB 11.8 re-engineering before both current-version testing baselines have been approved.
- Do not reopen completed activities without new evidence.

The programme supplements, and does not replace, the existing repository development, architecture, database, documentation and release requirements.
