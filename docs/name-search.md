# Search botanical names and active plants

The name-search box is in the top navigation. On a phone or tablet, open the
navigation menu first. The header name-search box stays visible on the results page and displays the current query. The results page also has its main search field.

Enter part or all of a botanical name and select Search. For example:

- `Catt` finds Cattleya and matching species/hybrids.
- `mossiae` finds matching species, including their genus in the displayed name.
- `Cattleya mossiae` narrows the results to names containing both words.

The search uses genus names and the existing combined taxon display names. It
also searches active plants by botanical name, plant tag and optional plant name.
It does not search notes or locations. All words must occur
in the botanical name, or in the combined botanical name/tag/plant name for
plant results, in any order. Matching is case-insensitive and uses the app's
utf8mb4_unicode_ci collation; accents are preserved in displayed names. `%`, `_`
and quotes are literal text rather than search operators. There is no fuzzy
spelling correction.

Results are grouped in this order: **Genus**, **Species / Hybrids**, **Plants**.
Sections without matches on the current page are omitted. Genus and taxon results
include inactive entries, labelled accordingly, and system-managed placeholders.
Plant results include only records where `isActive = 1` and `endDate IS NULL`;
inactive taxonomy does not itself exclude an otherwise active plant. Each plant
shows its tag, optional plant name and location from the existing plant view.
Plant results open Plant Details; genus/taxon results open their respective Details. Back to search results restores the query, result page and selected
item. The search page's own Back returns to the originating page.

Each section is sorted by name and paged independently at 30 matches per page
(up to 90 total), with shared Previous/Next links. Next advances all sections;
sections with fewer pages disappear once exhausted. Plant ties use tag and ID. A new
query starts at page one. Blank input does not list the entire database. Input is
limited to 100 characters. Paging is bounded to 10,000 result pages to avoid
unbounded offsets. Search is read-only; no database migration or new package is
required.

## Developer checks

    dotnet run --project tests/NameSearch.Checks/NameSearch.Checks.csproj

The checks exercise normalization, page-handler validation, result routing and
the actual MariaDB provider's SQL translation, including the existing name
sources and active-plant lookup, case-insensitive collation, server-side paging and exclusion of notes.
SQL translation checks do not connect to a database.

Browser checks use real Razor pages with sample results; live-database matching
and device-specific behaviour still need the acceptance checks below.

Before release, test against the actual development MariaDB database: genus-only,
species-only, hybrid-only and combined names; mixed case; accented names; inactive
records; literal punctuation; paging; and Details/Back. This confirms the live
database's character sets/collations and data behave as expected. The isolated
browser tests do not establish that live-database result matching has been tested.

Plant acceptance checks: search a botanical name shared by multiple plants, a
plant tag and an optional plant name. Confirm deleted and ended plants are absent,
and active plants with inactive taxonomy remain searchable. Open a plant and use
Back to verify the search page/query/item anchor is retained. Check grouped
paging with more than 30 matches in one category and fewer in another.
