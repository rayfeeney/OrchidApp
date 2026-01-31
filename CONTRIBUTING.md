# Contributing to OrchidApp

This repository is deliberately strict. Automation and validation are not advisory; they are the contract.  
Contributions that bypass enforced workflows will be rejected.

This project contains two closely related areas of development:

- a rigorously validated MySQL database schema, which is considered foundational and authoritative
- a web application layer developed on top of that schema, which is the primary area of future work

All contributions, regardless of area, are expected to follow the same principles of reproducibility, automation, and explicit constraints.

---

## General principles

- The repository must remain reproducible from committed artefacts alone
- Manual or undocumented steps are not acceptable
- Local validation and CI must behave identically
- Generated artefacts must never be edited by hand
- If automation fails, the change is invalid

If you are not comfortable working within these constraints, this project is not a good fit.

---

## Mandatory setup

Before making any changes, you **must** run the setup script:

```powershell
pwsh scripts/setup.ps1
```

This configures required tooling and installs repository-specific Git hooks.
Commits made without running this setup are invalid and will fail CI.

## Types of contributions

### Database changes

The MySQL database schema is considered the primary source of truth.

All schema changes must:

- be made directly in a database instance
- rely on the pre-commit hook to export and normalise schema files
- result in committed artefacts that can rebuild the schema from scratch

Generated files under database/schema/ must never be edited manually.

Bypassing the pre-commit hook (for example using --no-verify) is not permitted and will result in CI failure.

## Web application changes

The web application is the primary consumer of the database schema and the main area of future development.

Web application contributions are expected to:

- treat the database schema as authoritative
- operate within existing constraints rather than bypassing them
- avoid introducing undocumented manual steps
- integrate cleanly with the existing repository structure and CI

Web application code does not exempt a contributor from repository-wide rules around validation, commits, and reproducibility.

### Not permitted

Web application contributions must not:

- manually modify generated schema files
- bypass database constraints in application logic
- introduce schema changes without following the database workflow
- assume application convenience overrides database correctness

## Commits and validation

This repository uses enforced pre-commit hooks and CI validation.

- Hooks may modify and stage files as part of a commit
- Empty commits may be required to trigger schema export
- GitHub Desktop is not sufficient for all workflows

If a commit passes locally, it must pass in CI.
If it fails locally, do not push it.

## Pull requests

When opening a pull request, clearly state whether your changes are:

- database-focused
- web application-focused
- cross-cutting

This helps reviewers apply the correct context and level of scrutiny.

Pull requests that bypass validation, remove enforcement, or weaken guarantees will be rejected.

## Final note

This project prioritises correctness, clarity, and long-term maintainability over speed or convenience.

If something feels difficult, that is usually intentional.