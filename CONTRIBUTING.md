# Contributing to OrchidApp

Thank you for your interest in contributing to OrchidApp.

This project is deliberately strict. The automation, not individual judgement, defines what is acceptable. By contributing, you agree to follow the workflow and constraints described below.

---

## Before you start (mandatory)

Before making any changes, you **must** read and comply with the project contract defined in **README.md**, in particular:

- **Mandatory setup**
- **Prerequisites (required)**
- **How schema changes work**
- **Pre-commit enforcement**

If the prerequisites are not met or the setup script has not been run, commits will fail locally or be rejected by CI.

---

## Source of truth

- The **live MySQL database schema** is the authoritative source
- Files under `database/schema/` are **generated artefacts**
- Generated schema files must **never be edited manually**

Any contribution that edits generated schema files directly will be rejected.

---

## Expected workflow

Follow this workflow for all schema changes:

1. Ensure all prerequisites listed in `README.md` are installed and configured
2. Run the mandatory setup script if you have not already done so:

   ```powershell
   pwsh scripts/setup.ps1
   ```

3. Make schema changes directly in your local MySQL database
4. Commit your changes using Git
5. Allow the pre-commit hook to:
   - export the schema from the database
   - regenerate files under `database/schema/`
   - stage generated files automatically

If the pre-commit hook fails, **do not bypass it**. Fix the underlying issue and retry.

---

## Pre-commit rules

The pre-commit hook is a hard enforcement mechanism.

- It modifies and stages generated files
- It fails commits if schema export or validation fails
- Bypassing it (for example using `--no-verify`) is not permitted

Commits that bypass pre-commit enforcement will fail CI and must be corrected.

---

## Local CI validation (required before PRs)

Before opening a pull request, contributors are expected to run:

```powershell
pwsh scripts/ci-local.ps1
```

This script:

- creates a disposable MySQL instance using Docker
- rebuilds the schema using only committed files
- mirrors the GitHub Actions workflow exactly

If this script fails locally, CI will fail as well.

---

## Continuous integration expectations

GitHub Actions validates every push and pull request by rebuilding the schema from committed files only.

CI does not:

- use your development database
- tolerate schema drift
- allow missing or out-of-order objects

Your contribution must pass CI without manual intervention.

---

## What not to do

- Do not edit files under `database/schema/` manually
- Do not bypass Git hooks
- Do not commit schema changes without running local validation
- Do not rely on undocumented manual steps

---

## Scope of contributions

This project prioritises:

- correctness
- reproducibility
- clarity of intent

Contributions that weaken enforcement, introduce ambiguity or rely on tribal knowledge are unlikely to be accepted.

---

## Questions and discussion

If you are unsure how to proceed, raise a discussion or issue **before** attempting to bypass automation. The rules are intentional and enforced by design.

