# Architecture

This document describes the architectural philosophy and constraints of OrchidApp.

It is not a how-to guide and does not describe implementation details.  
Its purpose is to explain *why* the system is structured the way it is, and which boundaries are intentional and non-negotiable.

---

## Architectural overview

OrchidApp is a web application built on top of a rigorously designed and enforced MySQL database schema.

The architecture is deliberately layered:

- the **database layer** defines invariants, constraints, and lifecycle rules
- the **web application layer** implements behaviour and workflows within those constraints

The database is treated as the authoritative source of truth.  
The application layer exists to *use* those rules, not reinterpret or weaken them.

---

## Database as an invariant core

The MySQL schema is the architectural foundation of the system.

It is responsible for:

- enforcing structural integrity
- encoding lifecycle and identification rules
- preventing invalid or contradictory states
- guaranteeing reproducibility from committed artefacts alone

These properties are not optional and are not delegated to application logic.

The schema is treated as **source code**, with automation ensuring that:

- every committed version can be rebuilt from scratch
- drift between environments is detected immediately
- local development and CI behave identically

Any architecture that relies on the application layer to “fix up” invalid data is considered incorrect.

---

## Generated artefacts and enforcement

Schema files committed to the repository are generated artefacts.

They exist to:

- make the schema versionable
- enable deterministic rebuilds
- act as inputs to validation and CI

They are not hand-authored and must never be edited manually.

Enforcement via pre-commit hooks and CI is a core architectural feature, not a convenience.  
Bypassing enforcement invalidates the architecture.

---

## Web application as behavioural layer

The web application layer sits on top of the database and is responsible for *behaviour*, not *authority*.

Its responsibilities include:

- providing user-facing workflows
- orchestrating valid interactions with the schema
- presenting domain concepts without weakening constraints
- making correct usage easier than incorrect usage

The application must operate within the rules defined by the database.  
It must not duplicate, bypass, or silently override those rules.

---

## Evolution and change

Change is expected, but not everywhere equally.

- The **database layer** evolves cautiously and deliberately. Changes here are structural and high-impact.
- The **web application layer** is expected to evolve more rapidly as workflows and interfaces are refined.

Schema changes should be driven by clearly identified application needs, not speculative design or convenience.

Conversely, application complexity must not be pushed into the database to compensate for poor application design.

---

## Technology choices

Specific technologies, frameworks, or stacks for the web application are intentionally not mandated at this stage.

Architectural decisions should be guided by the same principles applied to the database:

- explicit constraints
- clear ownership of responsibility
- resistance to accidental complexity
- preference for correctness over convenience

The absence of an implementation today is an intentional state, not a gap in the architecture.

---

## Write strategy

- Atomic, independent entities (e.g. plantevent) may be written directly via EF Core.
- Temporal or inter-row dependent entities (e.g. plantlocationhistory) must be written exclusively via stored procedures.
- Triggers are permitted only to enforce absolute invariants, not to implement domain behaviour.

---

## Non-goals

This architecture does not aim to:

- optimise for rapid prototyping
- tolerate undocumented manual processes
- allow application logic to override data correctness
- prioritise developer convenience over reproducibility

If a workflow feels restrictive, that restriction is usually deliberate.

---

## Summary

The OrchidApp architecture is built around a simple but strict idea:

> **Invariants live in the database. Behaviour lives in the application. Enforcement lives in automation.**

Everything else follows from that.