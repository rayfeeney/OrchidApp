# OrchidApp repository instructions

## Working rules

Read [docs/index.md](docs/index.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before changing behaviour. Use [docs/documentation-map.md](docs/documentation-map.md) to identify the authoritative document for each area. Put new explanations, change summaries and reports under docs/, not at repository root. Keep required root files such as this file, README.md, CONTRIBUTING.md, RELEASE_NOTES.md and licence notices in their established locations.

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
