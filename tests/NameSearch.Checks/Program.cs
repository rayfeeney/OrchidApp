using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Services;
using OrchidApp.Web.Pages.Search;

var count = 0;
void Check(string label, bool passed) { if (!passed) throw new Exception(label); count++; }
Check("Blank query normalization", BotanicalNameSearch.NormalizeQuery(" \t\r\n ") == "");
Check("Repeated whitespace normalized", BotanicalNameSearch.NormalizeQuery("  Cattleya\t mossiae\n") == "Cattleya mossiae");
Check("Accents normalized and retained", BotanicalNameSearch.NormalizeQuery("  tre\u0300s  ") == "très");
Check("Literal punctuation retained", BotanicalNameSearch.NormalizeQuery("% _ ' & <") == "% _ ' & <");

var fake = new RecordingSearch();
var model = new IndexModel(fake);
await model.OnGetAsync(default);
Check("Initial page makes no search request", fake.Calls == 0 && !model.HasQuery);
model.SearchText = " \t ";
await model.OnGetAsync(default);
Check("Whitespace query makes no search request", fake.Calls == 0 && !model.HasQuery);
model.SearchText = new string('x', 101);
await model.OnGetAsync(default);
Check("Oversized query rejected without request", !model.ModelState.IsValid && fake.Calls == 0);
model = new IndexModel(fake) { SearchText = " Cattleya   mossiae ", ResultsPage = -5 };
using var cts = new CancellationTokenSource();
await model.OnGetAsync(cts.Token);
Check("Normalized multiword search passed to service", fake.LastQuery == "Cattleya mossiae");
Check("Negative page clamped", fake.LastPage == 1);
Check("Cancellation passed to database service", fake.Token == cts.Token);
Check("Result types and active status retained", model.Results.Count == 2 && model.Results[1].IsInactive && model.Results[1].DetailsPage == "/Setup/Taxa/Details");
Check("Genus result route", model.Results[0].DetailsPage == "/Setup/Genera/Details");
Check("Has-more retained", model.HasMore);
model.ResultsPage = int.MaxValue;
await model.OnGetAsync(default);
Check("Large page clamped without integer overflow", fake.LastPage == BotanicalNameSearch.MaxPage);
Check("Search result navigation label", AppNavigation.Label("/Search?q=Cattleya&resultsPage=2") == "Back to search results");
var returnUrl = "/Search?q=Cattleya%20mossiae&resultsPage=2&ReturnUrl=%2FSetup#result-taxon-9";
Check("Search return context survives nested details links", AppNavigation.Parent(AppNavigation.WithReturn("/Setup/Taxa/Details/9", returnUrl)) == returnUrl);
Check("Placeholder labelled separately", new NameSearchResult { Kind="taxon", IsPlaceholder=true }.Label == "Genus placeholder");

// Use the actual MariaDB provider to translate the real union/filter/paging
// expression. ToQueryString never connects to or modifies a database.
var options = new DbContextOptionsBuilder<OrchidDbContext>()
    .UseMySql("Server=127.0.0.1;Database=search_translation_only;User=test", new MariaDbServerVersion(new Version(10,11,0))).Options;
using var db = new OrchidDbContext(options);
var query = BotanicalNameSearch.BuildQuery(db.Genera.AsNoTracking(), db.TaxonIdentities.AsNoTracking(), "Cattleya mossiae")
    .Skip(BotanicalNameSearch.PageSize).Take(BotanicalNameSearch.PageSize+1);
var sql = query.ToQueryString();
Check("Both authoritative name sources in SQL", sql.Contains("`genus`") && sql.Contains("`vtaxonidentity`"));
Check("Results merged server side", sql.Contains("UNION ALL"));
Check("Explicit case/accent-insensitive collation", sql.Contains("COLLATE utf8mb4_unicode_ci"));
Check("Paged server side", sql.Contains("LIMIT") && sql.Contains("OFFSET"));
Check("Multiword match uses AND", sql.Contains(" AND "));
Check("Matching uses name columns", sql.Contains("`genusName`") && sql.Contains("`displayName`"));
Check("Notes are not searched", !sql.Contains("`taxonNotes`") && !sql.Contains("`growthNotes`") && !sql.Contains("`genusNotes`"));
var literalSql = BotanicalNameSearch.BuildQuery(db.Genera, db.TaxonIdentities, "%_' OR 1=1").ToQueryString();
Check("Literal search translated as substring lookup", literalSql.Contains("LOCATE") || literalSql.Contains("LIKE"));
Check("Stable result ordering", sql.Contains("ORDER BY") && sql.Contains("`Kind`") && sql.Contains("`Id`"));
// Verify the empty service guard before it could query an unconfigured DB.
using var unconfigured = new OrchidDbContext(new DbContextOptions<OrchidDbContext>());
Check("Empty service input never opens database", (await new BotanicalNameSearch(unconfigured).SearchAsync(" ", 1, default)).Results.Count == 0);
Console.WriteLine($"{count} name-search checks passed.");

sealed class RecordingSearch : IBotanicalNameSearch
{
    public int Calls { get; private set; }
    public string? LastQuery { get; private set; }
    public int LastPage { get; private set; }
    public CancellationToken Token { get; private set; }
    public Task<NameSearchPage> SearchAsync(string query, int page, CancellationToken cancellationToken)
    {
        Calls++; LastQuery=query; LastPage=page; Token=cancellationToken;
        return Task.FromResult(new NameSearchPage([
            new() { Id=7, Name="Cattleya", Kind="genus" },
            new() { Id=9, Name="Cattleya mossiae", Kind="taxon", IsInactive=true }], true));
    }
}
