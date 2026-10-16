# Environmental summary platform support

The home-page environmental summary is supported only when the OrchidApp server
runs Linux on ARM or ARM64 (the Raspberry Pi deployment).

Windows (including Windows ARM), Linux x86/x64, and other operating systems skip
the environmental-summary query entirely and hide the section. Their home page
does not require the environmental tables or views to exist. The check concerns
the server, not a phone or Windows browser connecting to a Raspberry Pi.

Linux ARM/ARM64 continues to execute the original query. Missing environmental
objects there remain a genuine deployment problem; this change does not catch or
hide those database failures.

No schema changes, deletion of environmental objects or new packages are needed.
Existing schema installation/migration behaviour is unchanged. Rebuild and
distribute an updated Windows installer for users of the affected older build;
restarting or reinstalling the same older build will not add this code fix.

## Verification

    dotnet run --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj

Checks cover every runtime architecture enum value for Linux/non-Linux policy,
ARM32/ARM64 support, Windows ARM exclusion and the current host. On an unsupported
host, the real home-page handler runs successfully with an unconfigured database
context that cannot query any view. Live Raspberry Pi data access still needs a
device/deployment smoke check before release.
