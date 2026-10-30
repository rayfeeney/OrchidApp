# Documentation correction handover

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

Baseline: supplied OrchidApp-clean.zip. Documentation corrected 24 October 2026. The original Downloads ZIP and live repository were not modified; this is an updated working snapshot for review/integration, not an installed app or deployment package.

## Delivered

- Root AGENTS.md makes documentation impact checks part of every code/SQL/config/script/packaging change, requires new supporting docs under docs/, and moves inapplicable/superseded docs to docs/history/ with incoming links updated. It retains the clean source ZIP command.
- README and CONTRIBUTING now route developers to one setup guide, schema-only creation contract and document ownership map. Requirements and incomplete implementation are explicitly separate.
- General installation is independent of the owner's bespoke monitoring. The local monitoring guide describes actual calculations and pending explicit installation opt-in; no imaginary setting or external feed setup is required of other users.
- Linux and Windows operating guides describe known backup/restore/creation limits, select/preserve exact recovery inputs and avoid promising unimplemented safeguards. Browser client setup is separate from incident investigations.
- Seven Word originals were corrected while preserving all embedded screenshots. Current release notes identify the v1.3.0 source without inventing a release date; historical releases, superseded recent deliveries and fixed evidence remain in history.
- [The 20-item code backlog](../code-change-backlog.md) records open fixes, affected files, priority, dependencies and acceptance. Application code, SQL, scripts, config and CI are unchanged. The bundled descriptive third-party notice matches the root note; licence texts are unchanged.

## Validation

Current local document links and heading anchors were checked with no unresolved target. All seven revised Word guides were rendered through installed Word and inspected as 77 pages; recovery-section flow/title colours were corrected. Embedded image bytes were compared to the original ZIP and are unchanged. The packaged LibreOffice renderer was unavailable; Word PDF export and PNG inspection supplied the visual check. See [validation record](documentation-validation.json).

No application build, database creation/migration, grant, backup/restore, installer or physical-device test was executed. Those belong to the pending implementation/acceptance work. Setup guides stop at actual code prerequisites instead of recommending historical migration replay or a broken rebuild as a workaround. Preserved screenshots illustrate workflows and can contain older UI styling/version labels; they are not evidence of a tested current release or fresh device run.

## Integrating the delivery

Extract the updated ZIP into a separate review directory. Do not overwrite an installed app or replace a live repository wholesale: the clean snapshot intentionally omits Git history, local secrets, dependencies, runtimes and collection data. Compare/merge the document changes into your checkout. Use [the change manifest](documentation-change-manifest.json) to apply recorded path retirements as moves into history rather than leave stale originals beside the new guides. Preserve your .git, .env/local settings, working code changes and user data.

The manifest lists original-to-history moves, modified existing files and added files. It excludes its own content hash to avoid a self-referential checksum. History evidence carries its original hashes/context; it is not silently regenerated to match the edited current guide. Review reports also preserve original snapshot paths and earlier findings, with the later owner clarifications authoritative in the current guides/backlog.

## Code work after documentation

All 20 code items remain open. Start with schema-only portable creation/baseline and CI (C01–C05), developer tooling (C16), and monitoring default-off installation isolation (C03). Prioritise source-aware backup, compatible settings restore, recovery/retention and migration-state handling (C06–C10), manual lifecycle closure (C11), and paired portable Linux recovery (C17). Remaining policy, temporal/image/readiness and package/check coverage work is C12–C15 and C18–C20. Each closure must update its affected document owner and record actual validation.
