# OrchidApp

**Note:** This repository uses a **required pre-commit hook** to capture database schema changes. Please complete the setup steps below before committing.

---

## Repository setup (Windows + GitHub Desktop)

This repository treats the **database schema as source code**.

During development, schema changes are made **directly in the database**. A required pre-commit hook captures a complete snapshot of the database schema and commits it to Git. Continuous Integration (CI) then validates that the committed snapshot can be rebuilt cleanly from scratch.

This process is intentionally strict to prevent hidden schema drift and ensure long-term reproducibility.

---

## What the pre-commit hook does

The required pre-commit hook runs automatically before every commit and:

- Discovers all schema objects from the database
- Exports schema objects to `database/schema`
- Creates files for new objects
- Removes files for dropped objects
- Normalises output for deterministic diffs
- Updates `database/checksums/schema.json`
- Warns about potential schema inconsistencies

The hook is versioned in this repository and must not be bypassed without justification.

---

## 1. Prerequisites

Install the following on your machine:

- **GitHub Desktop**
- **Git for Windows** (includes Git Bash)
- **PowerShell 7 (`pwsh`)**
- **MySQL client tools** (`mysql`, `mysqldump`)

Ensure `mysql` and `mysqldump` are available on your `PATH`.

You can verify with:

```bash
mysql --version
mysqldump --version
```

---

## 2. Clone the repository

Clone the repository using **GitHub Desktop** as normal.

Once cloned, open a **Git Bash** terminal in the repository root.

---

## 3. Configure database credentials (required)

Database credentials must **not** be hard-coded.

Set the following **user-level environment variables** in PowerShell:

```powershell
setx MYSQL_USER "your_mysql_user"
setx MYSQL_PASSWORD "your_mysql_password"
```

After running these commands:

- Close **all terminals**
- Restart **GitHub Desktop**

This step only needs to be done **once per machine**.

---

## 4. Enable the versioned Git hook (required)

This repository stores its Git hooks in a **versioned directory**.

From **Git Bash**, run **once** in the repository root:

```bash
git config core.hooksPath .githooks
```

This configuration:

- Applies **only to this repository**
- Does **not** affect other repositories
- Ensures all contributors run the same hook logic

---

## 5. Line endings (important)

This repository enforces **LF line endings** for hooks and scripts.

Normally, no action is required.

If GitHub Desktop shows a line-ending warning, run once from Git Bash:

```bash
git add --renormalize .
```

Then commit the result.

---

## 6. Verify the setup

Make a small change in the database and commit using **GitHub Desktop**.

You should see output similar to:

```
Exporting schema from localhost:3306 as <user>
Updated tables/...
Checksum file updated
```

If no schema changes exist, the hook will run quietly.

---

## 7. Important rules

- **Do not** manually edit files in `database/schema`
- **Do not** manually edit files in `database/checksums`
- **Do not** selectively commit generated files
- Schema changes must be made in the **database**, not by editing build or export scripts
- The checksum file is intentionally committed and auto-generated

Violations of these rules may result in CI failure or rejected pull requests.

---

## 8. Authority model (important)

- During development, the **database is the source of truth**
- The pre-commit hook captures a **complete schema snapshot** into Git
- Git represents the authoritative record of that snapshot
- CI rebuilds a database from the committed snapshot and validates reproducibility
- CI does **not** generate or modify schema artefacts

CI failure blocks merge, not push.

---

## 9. Why this process exists

This process ensures:

- Database-first development
- Complete and accurate schema snapshots
- Deterministic, reviewable diffs
- No hidden or accidental schema drift
- Consistent behaviour across machines, environments, and CI rebuilds
- Long-term maintainability

The process is intentionally strict in validation, but flexible during development.

---

If you are unsure about any part of this process, **ask before committing**.
