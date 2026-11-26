# Windows Sandbox release acceptance

Run from the OrchidApp repository on the Windows DEV PC. Each run creates a new Sandbox with networking and clipboard sharing disabled. It shares only a read-only test input directory and a separate writable evidence directory. The guest refuses an existing OrchidApp installation, existing collection state or occupied ports.

Prepare these inputs:

- The published v1.4.1 Windows installer and sanitised v1.4.0 specimen identified in the [Activity 05 record](../../docs/testing/activity-05-review.md). Optionally supply the exact published v1.4.0 installer to exercise the historical application upgrade in a second fresh Sandbox. The harness pins all three release hashes and checks the copies again inside Sandbox.
- Synthetic large JPEG and HEIC images, such as 5120 × 3840.
- A self-contained x64 Windows Python 3.9+ directory with its standard library and the [pinned Playwright requirements](../SharedBrowser.Checks/requirements.txt) installed under `Lib/site-packages`. A virtual environment that points to a host Python path is unsuitable. Prepare a separate browser directory with `PLAYWRIGHT_BROWSERS_PATH` set and run `python -m playwright install chromium` on the host. Stage only the required runtime and test inputs.

```powershell
pwsh ./tests/WindowsSandbox.Checks/New-SandboxRun.ps1 -Installer <published-exe> -Specimen <specimen-zip> -Jpeg <large-jpeg> -Heic <large-heic> -PythonRoot <portable-python> -BrowserRoot <chromium-directory> -Launch
```

Omit `-Launch` to generate the configuration only. Add `-PreviousInstaller <published-v1.4.0-exe>` to create a historical upgrade run. Close each Sandbox after its report is written. The script does not remove the host evidence directory.

The clean run installs the release, verifies the launcher-owned web and database listeners, restores the exact specimen through the launcher, runs the shared Chromium suite, creates and validates a managed backup, restarts and reopens the browser witness, restores the generated backup, and checks media and uninstall preservation. The upgrade mode stages the historical specimen through the known offline restore path before installing v1.4.1 over it. The published versions are unsigned. Record any host security policy that prevents the installer from running.

Inspect `report.json`, `browser.log`, installer logs and the launcher log under the emitted evidence directory. A failed or incomplete stage does not establish acceptance. The launcher run exercises local ZIP restore and an in-place round trip in the disposable Sandbox. Separate-target restoration and provider-specific OneDrive evidence remain separate checks. This is an application upgrade on the packaged 10.11 runtime. The MariaDB 11.8 engine upgrade remains part of the later programme.

## First published-package run

On 26 November 2026, the verified v1.4.1 installer deployed successfully in Windows Sandbox. The launcher reported `1.4.1+build.0.5dc488812872b60e8655a67b5ef4676347b5e47a` and bundled MariaDB `10.11.16`. The fresh database reached readiness and the application opened. The automatic safety backup failed because Windows PowerShell could not load `Microsoft.PowerShell.Archive` for `Expand-Archive` in the packaged backup contract. The first harness revision then timed out waiting for the launcher window. The harness now checks readiness and backup outcome separately and records a module-load diagnostic when this failure recurs.

Specimen restore, shared browser writes, backup round trip, uninstall and historical upgrade were not verified in that run. Keep the original Sandbox logs and treat the underlying module-load cause as unverified until reproduced with the additional diagnostic.
