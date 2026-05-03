# OrchidApp Documentation

This directory contains the **authoritative documentation** for OrchidApp.

It defines how the system is designed, how it behaves, and how it is operated.

This is not reference material.
This is the **operational and architectural contract** of the system.

---

# How to Use This Documentation

Start with the document that matches your intent:

| If you want to…                         | Read this                                         |
| --------------------------------------- | ------------------------------------------------- |
| Understand how the system is designed   | `architecture.md`                                 |
| Understand time, lifecycle and ordering | `temporal-design.md`                              |
| Install or upgrade the system           | `installation-upgrade.md`                         |
| Contribute safely to the project        | `../CONTRIBUTING.md`                              |
| Operate backups and recovery            | `OrchidApp-MariaDB-Backup-and-Restore-Runbook.md` |

Each document is authoritative within its domain.

They are designed to work together as a single system.

---

# Documentation Structure

The documentation is intentionally split by responsibility:

## Architecture - System Contract

```text
architecture.md
```

Defines:

* System invariants
* Layer responsibilities
* Enforcement boundaries
* Non-negotiable rules

This is the **source of truth** for how OrchidApp must behave.

All other documents must align with it.

---

## Temporal Design - Domain Behaviour

```text
temporal-design.md
```

Defines:

* Narrative vs structural time
* Lifecycle boundaries
* Temporal ordering rules
* Mutability constraints

Temporal behaviour is part of the core system contract.

---

## Installation & Upgrade - Execution Model

```text
installation-upgrade.md
```

Defines:

* How to install the system from scratch
* How to upgrade safely using migrations
* The deterministic deployment model

This is the **only valid procedure** for deployment.

---

## Contributing - Change Control

```text
../CONTRIBUTING.md
```

Defines:

* How changes must be made
* What is permitted and not permitted
* How enforcement (CI, hooks, migrations) works

This protects the architectural contract.

---

## Backup & Restore - Operational Safety

```text
OrchidApp-MariaDB-Backup-and-Restore-Runbook.md
```

Defines:

* Backup architecture
* Restore procedures
* Disaster recovery

This protects system state.

---

# System Model Summary

OrchidApp is built on a strict separation of responsibility:

* **Database** - enforces invariants and lifecycle rules
* **Application** - orchestrates valid behaviour
* **Automation** - enforces reproducibility and correctness
* **Operations** - protects and recovers system state

No layer may weaken another.

---

# Core Principles

The entire system follows these rules:

* The database is authoritative
* Schema is treated as source code
* Migrations control all structural change
* Generated artefacts are never edited manually
* Backups are only valid if restore succeeds
* Production behaviour must be reproducible

If a workflow conflicts with these principles, it is incorrect.

---

# Deterministic System Guarantee

At any point in time:

* The database can be rebuilt from committed artefacts
* The application can be redeployed from source
* The system state can be restored from backups

If this is not true, the system is in an invalid state.

---

# Final Principle

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

Everything in this documentation exists to uphold that principle.
