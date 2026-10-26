# C01–C20 upgrade action checklist

Changes only: four modified repository files and one added file, plus this CHANGELOG.md. No deletions or moves. Documentation only: no code, schema, private settings, credentials or data changes.

## Apply

Extract over the repository root containing OrchidApp.sln. Start with docs/upgrade-checklist.md. This adds no deployment automation, schedule or service change and does not execute an upgrade.

The maintained checklist separates Windows/Linux, release preparation/on-machine actions, one-time/recurring/failure actions and all C01–C20 coverage. Unfinished C11–C15/C18–C20 requirements remain visibly pending; this is not certification that all twenty items can be deployed. Future C-item changes must keep it current. A release-specific private completed copy is the initial manual record; the eventual tracking/automation choice remains undecided.

## Files

| Change | Path | Purpose |
| --- | --- | --- |
| Modified | AGENTS.md | Require future C-item changes to maintain platform deployment actions and release acceptance records. |
| Modified | CONTRIBUTING.md | Add the checklist update requirement to implementation/release workflow. |
| Modified | docs/index.md | Make the action checklist the starting point for upgrades. |
| Modified | docs/documentation-map.md | Assign one owner for cross-platform upgrade actions. |
| Added | docs/upgrade-checklist.md | Add Windows/Linux action lists, all twenty issue mappings, pending decisions and a private per-machine completion record. |

## Validation

All twenty issue rows, local Markdown link targets, merge markers and exact ZIP entries/bytes were checked. Procedures were reviewed against the current backlog, platform contracts and Linux runbook. No application tests/build or Word edit/render was needed for this standalone documentation/process addition. Actual installed upgrade acceptance and unresolved C-item implementation remain pending.
