# C03 monitoring isolation - 24 October 2026

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

Implemented in the local review-work/OrchidApp source copy. No live installation or owner service configuration was changed.

## Behaviour

Monitoring:Enabled is false in distributed appsettings.json and defaults false when absent. Startup resolves an immutable installation policy. True additionally requires Linux ARM/ARM64. The Home handler checks it before summary, chart or net-cost access. Existing Razor guards omit monitoring markup and scripts. Public static files remain accessible by URL.

Owner activation uses Monitoring__Enabled=true in private service configuration outside replaced application files, followed by restart. Existing installations without that override now remain disabled. Preserve the override during upgrades. General users need no feeds, grants or importers; those remain in the separate owner guide. No database/schema or historical migration changes were required.

## Validation

- EnvironmentSummary.Checks: 163 checks passed, covering absent/false/true settings and all runtime architecture values on Linux/non-Linux, providerless Home query avoidance, owner override precedence, and real compiled Home rendering on simulated general Linux ARM64 with no monitoring objects or database provider.
- The Home HTTP check initially hit sandbox loopback restrictions; the same check passed with local networking allowed.
- GreenhouseCharts.Checks: 61 checks passed with isolated calculation fixtures.
- Build during these checks succeeded. NuGet vulnerability lookup was unavailable (NU1900); this was not a compilation failure.

Policy and configuration tests simulate host combinations; they do not prove the owner Raspberry Pi, installed upgrade configuration preservation or live monitoring feed access. Verify the private opt-in on that device, Home summaries/charts/net costs and service restart after an app upgrade before fully closing C03. No production configuration or grants were modified.

## Documentation

Updated backlog/order, activation boundary, owner monitoring guide, architecture, developer setup, contributor guide, documentation index, Linux installation/restore guidance and release notes. Historic reports remain unchanged. Next agreed step is C01+C02 after C03 device acceptance.
