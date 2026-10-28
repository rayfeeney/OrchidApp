# Plant-event validation messages: CHAT-R01–R03

The add-event handlers rejected invalid dates and a missing repotting medium by adding field-specific model errors. The form used a `ModelOnly` summary but omitted message elements for those fields, so the field could be highlighted without explaining the rejection. Historical specimen testing found three examples; fresh current-source HTTP tests reproduced the same problem.

## Change

`Pages/Plants/Events/Add.cshtml` now renders field errors beside the observation, move and repotting dates, flowering start/end dates, the new repotting medium and observation notes. The notes message explains an empty observation instead of silently redisplaying it. The existing global summary remains for model-level errors.

No handler, date rule, transaction, database schema/history, existing record or photo file is changed. The edit-event date fields already had their corresponding message elements; no edit behaviour or optional legacy-medium policy is changed. There is no new migration, setting or startup command. The historical specimen remains unchanged.

## Regression checks

`tests/LifecycleClosure.Checks/ValidationMessages.Checks.py` runs from the existing `Database.Checks.ps1` runner against its generated upgraded and schema-only databases. It submits real HTTP forms with cookies and antiforgery tokens, then checks actual rendered field-message text and unchanged stored records after rejection. It covers future/before-acquisition dates for observation/move/repotting, flowering start/end errors, missing repotting medium, empty observation notes, malformed date binding, and corrected valid saves/reopen after rejection.

Run through the existing isolated lifecycle command and its explicit disposable-server credentials:

```powershell
pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1
```

The lifecycle CI job already invokes that runner. No separate job or database is added. These checks do not run against an installed collection or read the private development `.env`.

## Actual local validation

On 28 October 2026, the current extracted review mirror was built and hosted on Windows AMD64 with .NET SDK 9.0.315 targeting net8.0, MariaDB 10.11.16, new private database data directories and generated canonical-schema databases. No existing development/collection server was used. Git revision is unavailable for this extracted mirror.

- Before the view correction, nine test methods ran and reported 13 failing field-message assertions/subtests, reproducing the original three symptoms and related missing date/note messages. The valid correction/save cases still worked.
- After the view correction, all nine new HTTP test methods passed. Rejected POSTs left stored records unchanged; corrected observation/flowering/repotting submissions saved and reopened.
- All 16 related existing ended-plant/date-policy tests passed. The Release build succeeded with zero warnings and zero errors.
- The two maintained plant-management Word guides (Windows 03 and Linux/Pi 02) were reviewed for impact. Neither specifies these error strings or a validation-message workflow. The controls and valid-state appearance are unchanged, so their existing 22 screenshots each remain applicable; neither Word file was edited.

GitHub CI on the applied/merged revision, Linux/current-ARM64 execution, browser visual/JavaScript interaction and actual installed-machine acceptance remain pending. The historical specimen's older error-display failures are not rewritten as passes. This patch does not complete C18 upgrade/recovery acceptance.

See the [Windows/Linux upgrade checklist](../upgrade-checklist.md#chat-r01r03-plant-event-message-correction) and [test inventory](../testing-evidence.md).
