# OrchidApp navigation update

This source update implements consistent app Back/Cancel destinations across the
reviewed pages. It assumes the shared Genus rich-notes update is already installed
and includes the latest Genus/Taxa formatting in the page files it replaces.

## Install

1. Stop your development app with Ctrl+C and commit/back up your current source.
2. Extract the ZIP into the OrchidApp repository, preserving the `src/` paths.
   Review replacements if your source has changed since the uploaded snapshot.
   Do not copy the files into a published runtime directory instead of the source.
3. Restart from the repository root:

       dotnet run --project .\src\OrchidApp.Web --launch-profile http

4. Open http://localhost:5285 and test the routes below.

No database migration, appsettings replacement, new NuGet package or runtime
dependency is required. Existing formatting helpers and licence files remain in
use. The ZIP contains source, optional checks and documentation only.

## Behaviour

- Back always has an explicit local destination. There is no history.back()
  fallback, so browser history cannot send the app button into the old loop.
- Blank, relative, external and self-pointing return destinations use sensible
  fallbacks. Known Index aliases and trailing slashes are treated consistently.
- Details returns to its originating list/report. Filters, nested return context
  and existing item anchors are preserved in generated return links.
- Edit forms have Cancel, returning to the originating view. Successful edits
  show updated Details, whose Back still leads to the original list/report.
- Genus Add now consistently shows the new Details page after saving; it no longer
  sometimes jumps straight to the list. Taxa and plant creation follow the same
  view/confirmation principle.
- Location and Growth media Details no longer overwrite the caller's context.
  Their lists use an explicit Setup fallback, rather than relative `Index`.
- Plant event save/remove routes retain the original Plant details address and
  its list/report context. Photos and lineage use explicit owning-plant fallbacks.
- New-plant, split and propagation confirmation Continue destinations carry
  intentional return context. A new child can return to its parent plant.
  Missing confirmation TempData also uses a safe view destination.
- Flowering and flowering-history report links, parent/child plant links and
  Quick Find now carry their originating page.
- Forms retain their validated ReturnUrl through POST and failed validation.
- Shared Back buttons name recognised destinations; form buttons use Cancel.
  Other unchanged informational pages without Back retain their existing navbar.

The browser's own Back button remains browser-controlled. Cancel navigates away
without saving; the change does not introduce draft recovery or unsaved-change
prompts. It preserves explicit item anchors already supplied by the app, rather
than capturing an arbitrary pixel scroll offset.

## Verification completed

- Release build: zero warnings/errors.
- 73 navigation checks: per-area fallbacks, local/self URL handling, nested query
  and fragment round trips through the actual plant return-link builder, event
  completion, child/new-record destinations, GET/POST page-filter behaviour,
  validation preservation and repeated-save stability.
- 31 browser assertions using OrchidApp's real compiled Razor pages and the new
  global filter in an isolated test host. Database reads used sample data and the
  successful Genus Add test used a substitute procedure executor. These included
  the former Setup/Taxa loop, explicit Index/trailing-slash routes, Edit Cancel,
  a nested return chain to Reports, invalid and successful Add submissions,
  unsafe/self targets, Taxa query/anchor preservation and Quick Find context.
- Existing 22 rich-notes checks still pass.

Optional source checks from the repository root:

    dotnet run --project tests/Navigation.Checks/Navigation.Checks.csproj
    dotnet run --project tests/RichNotes.Checks/RichNotes.Checks.csproj

The live database-backed event/photo/split/propagation operations and physical
mobile devices were not exercised here. Verify these on your development system
before rolling out the change.

## Local acceptance checks

1. Navbar Setup > each list > Details > Edit > Cancel > Details Back > list Back
   > Setup Back. This should reach Home without bouncing between pages.
2. Repeat after Save and invalid input. Also try adding a genus and a taxon.
3. Open a plant from each report, record/edit/remove an event, then Back from
   Plant details. It should return to the original report.
4. Plants > species list > plant > photos/lineage > Back repeatedly should restore
   the original route. Check parent/child links too.
5. Try new plant, split and propagation confirmation Continue, then Back. Check
   that no completed entry form or consumed confirmation is reopened by app Back.
6. Search by tag from a report and verify Back returns to that report.
7. Try bookmarked/new-tab entry, explicit /Index and trailing-slash list URLs.
8. Check list selection anchors and any actual filter/query state in use.

## Implementation

`AppNavigation` centralises URL validation, fallback destinations, labels and save
completion. `NavigationPageFilter`, registered with Razor Pages in Program.cs,
normalises bound ReturnUrl values before handlers and before rendering, including
failed POSTs. Page links/forms preserve context and shared partials provide the
explicit fallback even when a caller is missing.

Revert this source update and rebuild to roll back. No stored-data conversion is
needed for the navigation changes.
