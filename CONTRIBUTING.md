# Contributing guidelines

Thank you for contributing to this repository.

This project treats the **database schema as source code** and enforces consistency through automated tooling. Contributions are expected to follow the conventions and workflows described below.

These rules are not optional. They exist to prevent schema drift, reduce review overhead, and ensure long-term maintainability.

## 1. Core principles

All contributors must understand and follow these principles:

* The **database is the starting point** for schema changes
* Git is the **authoritative record** of the schema state
* Schema artefacts are **generated**, not hand-edited
* Consistency is enforced automatically via tooling
* Deviations must be explicit and intentional

## 2. Required local setup

Before making any commits, contributors **must** complete the repository setup described in `README.md`, including:

* Installing required tooling
* Setting database credentials via environment variables
* Enabling the versioned Git hook:

```git bash
git config core.hooksPath .githooks
```

Commits made without this setup may be rejected during review or by CI.

## 3. Database standards (authoritative)

This repository follows a defined set of **database design and naming standards**.

The **authoritative specification** is defined in:

```
[DatabaseStandards.sql](database/standards/DatabaseStandards.sql)
```

This file is the source of truth. Documentation elsewhere is descriptive only.

### 3.1 Summary of standards

Contributors are expected to comply with the following high-level principles when making database changes:

* Consistent and meaningful naming for:

  * Tables
  * Columns
  * Primary keys
  * Foreign keys
  * Constraints and indexes
* Predictable primary key patterns
* Explicit and appropriate data types
* Clear ownership and lifecycle semantics
* Avoidance of implicit or engine-specific defaults
* Schema objects must be self-describing and reviewable

Reviewers will assess changes against both the **[database standards](database/standards/DatabaseStandards.sql)** and these principles.

### 3.2 Relationship to tooling

The schema export scripts, checksum tracking, and CI validation **assume compliance** with these standards.

Non-conforming objects may result in:

* Export failures
* Unexpected diffs
* Checksum mismatches
* CI failures

Standards violations should be corrected at the database level, not patched in generated artefacts.

## 4. Making schema changes

### 4.1 What you must do

When changing the database schema:

1. Apply the change **directly to the database**
2. Commit your work normally
3. Allow the pre-commit hook to:

   * Export schema objects
   * Update checksums
   * Stage generated files

All generated changes must be committed together.


### 4.2 What you must not do

The following are explicitly disallowed:

*  Manually editing files in `database/schema`
*  Manually editing files in `database/checksums`
*  Bypassing the hook without justification
*  Committing schema changes without generated artefacts

If you believe an exception is required, explain it clearly in the commit message or pull request.

## 5. Pre-commit hook behaviour

This repository uses a **required pre-commit hook** that:

* Exports database schema objects
* Normalises output for deterministic diffs
* Tracks changes via checksums
* Warns about schema drift

The hook is versioned in `.githooks/pre-commit` and must not be modified locally without review.

## 6. Continuous integration (CI)

CI validation mirrors the behaviour of the local pre-commit hook.

CI may fail if:

* Generated schema files are out of sync
* Checksum state does not match exported objects
* Schema drift is detected

CI is the final enforcement mechanism. Local hooks are an early warning system.

## 7. Emergency hook bypass

A controlled hook bypass mechanism exists for exceptional circumstances (e.g. outages, hotfixes).

Bypassing the hook:

* Must be explicit
* Must be justified
* May still be rejected by CI

Bypassing without explanation is grounds for rejection during review.

## 8. Review expectations

When reviewing contributions, maintainers will expect:

* Schema changes to follow documented standards
* Generated artefacts to be present and correct
* No manual edits to generated files
* Clear intent and traceability

Pull requests that do not meet these expectations may be returned for correction.

## 9. Why this process exists

This process ensures:

* Schema-as-code discipline
* Deterministic, reviewable changes
* No hidden database drift
* Consistent behaviour across developers and CI
* Long-term maintainability

It is intentionally strict.


* If you are unsure about any part of this process, ask before committing.
