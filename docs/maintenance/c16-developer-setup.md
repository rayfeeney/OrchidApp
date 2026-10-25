# C16 developer setup evidence

## Delivered behavior

One explicit set of MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD values now serves setup, schema export and the generated ConnectionStrings__OrchidDb value. configure.ps1 uses a connection-string builder to quote credentials, requires an absolute Storage__UploadRoot, selects Development and disables bespoke monitoring. The committed Development JSON contains only logging/detailed-error settings. No password, endpoint or personal photo path remains there.

setup.ps1 checks PowerShell, Git, .NET SDK 8+ and .NET/ASP.NET 8 runtimes, resolves one MariaDB 10.11 client/dump executable, checks server connectivity/version and activates the local hook. It never creates accounts or database objects. The client resolver supports explicit paths with spaces and Windows/PATH discovery; obsolete MYSQL account aliases are removed from setup. Environment configuration is process-local and must be inherited by the Git client that commits.

The exporter now requires the explicit endpoint, uses --no-defaults and TCP for both clients, sets UTF-8 explicitly and restores the prior MYSQL_PWD value. This exposed a pre-existing case-insensitive PowerShell variable collision between the DumpArgs parameter and dumpArgs local variable. The native argument array now has a distinct name, avoiding duplicated options; the real hook and migration exporter integration checks cover the corrected invocation. No generated schema, schema checksums, manifest or historical migration SQL is changed in this delivery.

run.ps1 performs the actual PhotoPipeline probe before starting the source app. Windows x64 uses the complete upstream libvips 8.18.2 archive with a pinned SHA-256; the smaller native NuGet binary alone lacked DLLs required by the current NetVips 2.4.2 binding during investigation. No new production NuGet dependency was added. -LibVipsOnly avoids the packaging script's MariaDB/Chocolatey route. Cached runtime checks require libvips/GLib/GObject DLLs and the exact vips version. The child PATH is set for source startup and restored afterward. -CheckOnly probes without starting the app; -Url permits a separate development HTTP port.

The probe creates a unique directory below the configured upload root, processes a generated PNG, saves separate JPEG photo and thumbnail files, fully decodes both, checks their dimensions and removes only its probe directory. Linux uses system libvips. The local validation wrapper now runs the existing disposable baseline/migration database suites rather than obsolete MySQL Docker/Assemble-Schema tooling.

## Validation performed

Local Windows x64 testing used the installed SDK 9.0.315, .NET/ASP.NET 8 runtimes, PowerShell 7, MariaDB 10.11.16 and the downloaded full libvips 8.18.2 archive. Tests used disposable workspace data and generated database names on a separate loopback port, never the live collection.

- 17 development configuration checks passed: explicit non-default endpoint, conflicting MYSQL aliases ignored, database/account/password alignment including quotes/semicolons, monitoring/charset, missing values, invalid port/database and relative upload rejection.
- Windows native probe passed: generated 640x480 PNG saved/reopened as a 640x480 JPEG and a separate 300x225 thumbnail, with full native decoding. Both first restore and cached-runtime paths were exercised.
- setup.ps1 passed against an isolated MariaDB server in a disposable Git checkout. The checkout's real pre-commit hook exported and staged schema/checksum artifacts successfully after schema-only creation and seeded baseline completion.
- The new run.ps1 started the source app against that development target on a separate loopback HTTP port. Home, Plants and the fixture plant's Photos page returned HTTP 200. An antiforgery-protected multipart PNG upload succeeded; the photo page reopened; the separate main/thumbnail JPEGs were fetched over HTTP and matched their stored bytes.
- All 53 migration database checks passed after the exporter endpoint/argument changes, including future-once upgrades, failed-DDL handling, pending-marker export refusal and developer export integration. The 10 child-process protocol checks also passed.
- Release web build passed with zero warnings/errors. PowerShell syntax checks passed. Local native-project restore reported NU1900 when vulnerability metadata could not be fetched; the native build/probe still succeeded. This is not a successful online vulnerability audit.

## CI and remaining acceptance

The workflow now runs configuration checks and the real native photo/thumbnail probe on both Ubuntu and Windows. Ubuntu installs libvips-tools; Windows uses the restored full pinned runtime before the existing packaging step. The schema export job now supplies MARIADB_DATABASE explicitly. These newly added CI steps have not yet been confirmed in GitHub Actions.

Local verification used already installed development tools, not a completely fresh OS. Installing all prerequisites on a clean Windows/Linux machine, the Linux source run/HTTP photo workflow, Pi hardware, real installer upgrades and backup/recovery remain separate acceptance. The default source URL was occupied locally, so the successful test used run.ps1 -Url with a separate loopback port. Native readiness here does not add comprehensive readiness checks to ordinary Production hosting (C19).

The owner already confirmed the corrected C04 Linux CI passed. C05, broader CI database acceptance, is next in the agreed order. Use [developer setup](../development-setup.md) for the maintained procedure.
