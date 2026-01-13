# Architecture and philosophy

This document captures the architectural philosophy and design decisions behind OrchidApp. It exists to keep the README lean while preserving the reasoning that informs the project’s structure and constraints.

Nothing in this document overrides the rules defined in README.md. README.md is the contract. This document explains *why* that contract exists.

---

## Design goals

OrchidApp is designed to demonstrate how a database schema can be treated with the same discipline as application source code.

The primary goals are:

- deterministic schema builds
- early detection of schema drift
- identical behaviour locally and in CI
- minimal reliance on undocumented manual steps

The project intentionally favours correctness and reproducibility over convenience.

---

## Schema as code (but not hand-written)

The schema is treated as code in terms of:

- version control
- review
- reproducibility
- automated validation

However, the schema files themselves are **not hand-authored**.

The authoritative source is a live MySQL database. SQL files under `database/schema/` are generated artefacts produced by deterministic export scripts. Editing these files manually is equivalent to editing compiled output and is therefore forbidden.

---

## Authority boundaries

Clear authority boundaries are central to the design:

- **Database**: authoritative source of schema truth
- **Export scripts**: transform database state into deterministic files
- **Git repository**: authoritative record of what must be rebuildable
- **CI**: final arbiter of correctness

No single tool is trusted implicitly. Each layer validates the one below it.

---

## Git as the contract

Git does not merely store the schema; it defines the contract that must be honoured.

Any commit must contain everything required to:

- assemble the schema in the correct order
- rebuild the database from scratch
- detect missing or incompatible objects

If a schema cannot be rebuilt from the committed files alone, the commit is considered invalid regardless of local success.

---

## Automation-first enforcement

Rules are enforced by automation, not convention.

- Pre-commit hooks prevent invalid states from being committed
- Local CI scripts mirror GitHub Actions exactly
- CI performs a clean rebuild using only committed artefacts

This reduces reliance on personal discipline and ensures consistent behaviour across contributors and environments.

---

## Local and remote parity

A key principle is that local validation and remote CI must behave identically.

Developers are expected to detect failures locally using the same process CI uses. Surprises at pull request time are considered a design failure.

---

## Learning-oriented but production-minded

Although OrchidApp is a learning and reference project, it intentionally mirrors production-grade practices:

- disposable environments
- strict validation gates
- explicit contracts
- minimal hidden behaviour

The goal is not speed, but understanding and repeatability.

---

## Intentional constraints

Some constraints are intentional and not accidental:

- strict pre-commit enforcement
- no support for bypassing validation
- preference for rebuilds over incremental fixes

These constraints simplify reasoning about the system and make failure modes explicit.

---

## When to update this document

Update this document when:

- the core philosophy changes
- authority boundaries move
- new enforcement layers are introduced

Do not update this document for routine script or workflow changes. Those belong in README.md or CONTRIBUTING.md.

