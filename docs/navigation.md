# Back, Cancel and return navigation

The app carries an explicit local return destination between lists, reports,
Details and forms. This preserves the route by which the user reached a record.

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

## Implementation

`AppNavigation` centralises URL validation, fallback destinations, labels and save
completion. `NavigationPageFilter`, registered with Razor Pages in Program.cs,
normalises bound ReturnUrl values before handlers and before rendering, including
failed POSTs. Page links/forms preserve context and shared partials provide the
explicit fallback even when a caller is missing.

## Validation

From the repository root:

```bash
dotnet run --configuration Release --project tests/Navigation.Checks/Navigation.Checks.csproj
```

Checks cover URL validation, fallbacks, nested query/fragment preservation,
completion destinations and page-filter behaviour. They do not replace live
database-backed workflow checks or physical mobile testing.

## Acceptance checks

1. Navbar Setup > each list > Details > Edit > Cancel > Details Back > list Back
   > Setup Back. This should reach Home without bouncing between pages.
2. Repeat after Save and invalid input. Also try adding a genus and a taxon.
3. Open a plant from each report, record/edit/remove an event, then Back from
   Plant details. It should return to the original report.
4. Plants > species list > plant > photos/lineage > Back repeatedly should restore
   the original route. Check parent/child links too.
5. Try new plant, split and propagation confirmation Continue, then Back. Check
   that no completed entry form or consumed confirmation is reopened by app Back.
6. Use the header name search from a report, open a result and return to search
   results, then use Back to return to the report.
7. Try bookmarked/new-tab entry, explicit /Index and trailing-slash list URLs.
8. Check list selection anchors and any actual filter/query state in use.
