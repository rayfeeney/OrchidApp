**Note:** This repository uses a required pre-commit hook to manage database schema changes. Please complete the setup steps before committing.

## Repository setup (Windows + GitHub Desktop)

This repository uses a **required pre-commit hook** to automatically export and track the MySQL database schema on every commit.

The hook:

* Exports schema objects to `database/schema`
* Updates `database/checksums/schema.json`
* Warns about schema drift
* Runs automatically before each commit

Follow the steps below **once after cloning**.

## 1. Prerequisites

Install the following:

* **GitHub Desktop**
* **Git for Windows** (includes Git Bash)
* **PowerShell 7 (`pwsh`)**
* **MySQL client tools** (`mysql`, `mysqldump`)

Ensure `mysql` and `mysqldump` are available on your `PATH`.

You can verify with:

```bash
mysql --version
mysqldump --version
```

## 2. Clone the repository

Clone the repository using **GitHub Desktop** as normal.

Once cloned, open a **Git Bash** terminal in the repository root.

## 3. Configure database credentials (required)

Database credentials must **not** be hard-coded.

Set the following **user-level environment variables** in PowerShell:

```powershell
setx MYSQL_USER "your_mysql_user"
setx MYSQL_PASSWORD "your_mysql_password"
```

After running this, **close and reopen GitHub Desktop**
so it can see the environment variables.

This only needs to be done **once per machine**.

## 4. Enable the versioned Git hook (required)

This repository stores its Git hooks in a **versioned directory**.

From **Git Bash**, run **once** in the repo root:

```bash
git config core.hooksPath .githooks
```

This configuration:

Applies **only to this repository**
Does **not** affect other repos
Ensures everyone runs the same hook logic

## 5. Line endings (important)

This repository enforces **LF line endings** for hooks and scripts.

Normally, no action is required.

If GitHub Desktop shows a line-ending warning, run once from Git Bash:

```bash
git add --renormalize .
```

Then commit the result.

## 6. Verify the setup

Make any small change and commit using **GitHub Desktop**.

You should see output similar to:

```
Exporting MySQL schema...
Updated tables/...
Schema sync complete.
```

If no schema changes exist, the hook will run silently.

## 7. Important rules

* **Do not** edit files in `database/checksums` manually
* **Do not** edit files in `.githooks` unless updating hook logic
* Schema changes should be made in the **database**, not by editing `.sql` files
* The checksum file is intentionally committed and auto-generated

## 8. Troubleshooting

### The hook does not run

* Ensure this was executed:

  ```bash
  git config core.hooksPath .githooks
  ```
* Restart GitHub Desktop after setting environment variables
* Ensure `pwsh`, `mysql`, and `mysqldump` are on `PATH`

### Line-ending warnings in GitHub Desktop

Run:

```bash
git add --renormalize .
```

and commit once.

## Why this exists

This setup ensures:

Schema-as-code
Deterministic diffs
No hidden database drift
Consistent behaviour across machines and CI


### database/checksums/schema.json

This file is auto-generated on commit.
It tracks checksums of exported database schema objects
and must be committed. Do not edit manually.
