# Search genus, species and hybrid names

The name-search box is in the top navigation. On a phone or tablet, open the
navigation menu first. The header name-search box stays visible on the results page and displays the current query. The results page also has its main search field.

Enter part or all of a botanical name and select Search. For example:

- `Catt` finds Cattleya and matching species/hybrids.
- `mossiae` finds matching species, including their genus in the displayed name.
- `Cattleya mossiae` narrows the results to names containing both words.

The search uses genus names and the existing combined taxon display names. It
does not search notes, plant tags or individual plant names. All words must occur
in the name, in any order. Matching is case-insensitive and uses the app's
utf8mb4_unicode_ci collation; accents are preserved in displayed names. `%`, `_`
and quotes are literal text rather than search operators. There is no fuzzy
spelling correction.

Results identify genera, species/hybrids and system-managed genus placeholders.
Inactive entries are included and labelled. Select a result to open its existing
Details page. Back to search results restores the query, result page and selected
item. The search page's own Back returns to the originating page.

Results are sorted by name and shown 30 at a time, with Previous/Next links. A new
query starts at page one. Blank input does not list the entire database. Input is
limited to 100 characters. Paging is bounded to 10,000 result pages to avoid
unbounded offsets. Search is read-only; no database migration or new package is
required.

## Developer checks

    dotnet run --project tests/NameSearch.Checks/NameSearch.Checks.csproj

The checks exercise normalization, page-handler validation, result routing and
the actual MariaDB provider's SQL translation, including both existing name
sources, case-insensitive collation, server-side paging and exclusion of notes.
SQL translation checks do not connect to a database.

Browser checks used real Razor pages with sample results to verify search entry,
both result types, paging, Details/Back context, empty/oversized input, encoded
names and responsive navigation at phone, tablet and desktop widths.

Before release, test against the actual development MariaDB database: genus-only,
species-only, hybrid-only and combined names; mixed case; accented names; inactive
records; literal punctuation; paging; and Details/Back. This confirms the live
database's character sets/collations and data behave as expected. The isolated
browser tests do not establish that live-database result matching has been tested.
