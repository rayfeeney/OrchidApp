# Shared browser acceptance

Use a disposable OrchidApp installation with its own database and uploads, an active taxon available for plant creation, monitoring disabled, and a loopback HTTP listener. The browser test writes a uniquely named plant, an observation and two photos. Dispose of the fixture after collecting evidence. Use Python 3.9 or later and run the commands from the repository root.

```powershell
python -m pip install -r tests/SharedBrowser.Checks/requirements.txt
python -m playwright install chromium
python tests/SharedBrowser.Checks/checks.py --base-url http://127.0.0.1:53337 --disposable --jpeg path/to/large.jpg --heic path/to/large.heic
```

On Linux, use `python -m playwright install --with-deps chromium` to install Chromium and its system dependencies. The existing lifecycle runner accepts `-PythonExe python -SharedBrowser` to build two owned web/database fixtures and generate synthetic 5120 × 3840 JPEG and HEIC inputs using libvips with HEIF decode and encode support. CI uses this mode. The same browser command can run inside Windows Sandbox or on the Linux test machine once the respective platform runner starts the isolated installed application.

The suite covers readiness and home, plant creation and editing, search and navigation, observation rejection without a saved event followed by correction, and both distinct full-size photos and thumbnails. It prints a plant ID and name. After a platform runner has stopped and restarted the application, use `--reopen <plant-id> <plant-name>` in place of the photo arguments to verify readiness, search and the same gallery again. The lifecycle CI run uses source fixtures. Packaged and physical-device acceptance remain tracked by the [programme](../../docs/testing/automated-testing-mariadb118-plan.md).
