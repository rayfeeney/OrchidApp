# OrchidApp Documentation

This directory contains the **authoritative documentation** for OrchidApp.

It defines how the system is designed, how it behaves, and how it is operated.

This is not reference material.
This is the **operational and architectural contract** of the system.

- [OrchidApp Documentation](#orchidapp-documentation)
- [How to Use This Documentation](#how-to-use-this-documentation)
- [Documentation Structure](#documentation-structure)
  - [Architecture - System Contract](#architecture---system-contract)
  - [Temporal Design - Domain Behaviour](#temporal-design---domain-behaviour)
  - [Windows Upgrade Contract - Installer-Led Safety](#windows-upgrade-contract---installer-led-safety)
  - [Installation \& Upgrade - Execution Model](#installation--upgrade---execution-model)
  - [Contributing - Change Control](#contributing---change-control)
  - [Backup \& Restore - Operational Safety](#backup--restore---operational-safety)
- [System Model Summary](#system-model-summary)
- [Core Principles](#core-principles)
- [Deterministic System Guarantee](#deterministic-system-guarantee)
- [Final Principle](#final-principle)

---

# How to Use This Documentation

Start with the document that matches your intent:

| If you want to…                         | Read this                                                                  |
| --------------------------------------- | -------------------------------------------------------------------------- |
| Understand how the system is designed   | `architecture.md`                                                          |
| Understand time, lifecycle and ordering | `temporal-design.md`                                                       |
| Understand Windows upgrade safety       | `windows-upgrade-contract.md`                                              |
| Install or upgrade on Linux             | `user-guides/linux/installation-upgrade.md`                                |
| Install or upgrade on Windows           | `user-guides/windows/`                                                     |
| Contribute safely to the project        | `../CONTRIBUTING.md`                                                       |
| Operate Linux backups and recovery      | `user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md`        |
| Use Windows backup and recovery docs    | `user-guides/windows/`                                                     |

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

## Windows Upgrade Contract - Installer-Led Safety

```
windows-upgrade-contract.md
```

Defines:

* Installer-owned application files
* ProgramData-owned user data
* Legacy ZIP-era migration behaviour
* Mandatory pre-upgrade backup before legacy migration
* Safe-stop conditions
* Windows launcher responsibilities
* Windows installer responsibilities

This is the source of truth for Windows installer-led upgrade safety.

---

## Installation & Upgrade - Execution Model

Linux installation and upgrade behaviour is defined in:

```
user-guides/linux/installation-upgrade.md
```

Windows installer-led upgrade behaviour is defined in:

```
windows-upgrade-contract.md
```

Windows user-facing installation, backup and recovery documents live under:

```
user-guides/windows/
```

Public Windows upgrades must use the installer. They must not be performed by extracting a ZIP or package folder over an existing OrchidApp folder.

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

Linux backup and restore behaviour is defined in:

```
user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md
```

Windows backup, restore and recovery documentation lives under:

```
user-guides/windows/
```

Backups protect:

* MariaDB database state
* Uploaded plant images
* Runtime user settings required for recovery

Backups are only valid if restore succeeds.

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
