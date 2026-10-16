using System.Text;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Services;

public interface IBotanicalNameSearch
{
    Task<NameSearchPage> SearchAsync(string text, int page, CancellationToken cancellationToken);
}

public sealed class BotanicalNameSearch(OrchidDbContext db) : IBotanicalNameSearch
{
    public const int MaxQueryLength = 100;
    public const int PageSize = 30;
    public const int MaxPage = 10000;
    // Matches OrchidApp's existing connection/database collation policy.
    public const string NameCollation = "utf8mb4_unicode_ci";

    public static string NormalizeQuery(string? text) => string.Join(" ",
        (text ?? "").Normalize(NormalizationForm.FormC).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

    public async Task<NameSearchPage> SearchAsync(string text, int page, CancellationToken cancellationToken)
    {
        var query = NormalizeQuery(text);
        if (query.Length == 0) return new([], false);
        if (query.Length > MaxQueryLength) throw new ArgumentException("Search text must be 100 characters or fewer.", nameof(text));
        var rows = await BuildQuery(db.Genera.AsNoTracking(), db.TaxonIdentities.AsNoTracking(), query)
            .Skip((Math.Clamp(page, 1, MaxPage) - 1) * PageSize)
            .Take(PageSize + 1)
            .ToListAsync(cancellationToken);
        return new(rows.Take(PageSize).ToList(), rows.Count > PageSize && page < MaxPage);
    }

    // Keep matching and paging in MariaDB. Contains treats %, _ and quotes as
    // literal search text; all user terms are provider-generated parameters.
    public static IQueryable<NameSearchResult> BuildQuery(IQueryable<Genus> genera, IQueryable<TaxonIdentity> taxa, string text)
    {
        foreach (var term in NormalizeQuery(text).Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            genera = genera.Where(g => EF.Functions.Collate(g.Name, NameCollation).Contains(term));
            taxa = taxa.Where(t => EF.Functions.Collate(t.DisplayName, NameCollation).Contains(term));
        }
        var genusResults = genera.Select(g => new NameSearchResult {
            Id = g.GenusId, Name = EF.Functions.Collate(g.Name, NameCollation), Kind = "genus", IsInactive = !g.IsActive, IsPlaceholder = false });
        var taxonResults = taxa.Select(t => new NameSearchResult {
            Id = t.TaxonId, Name = EF.Functions.Collate(t.DisplayName, NameCollation), Kind = "taxon",
            IsInactive = !t.GenusIsActive || !t.TaxonIsActive, IsPlaceholder = t.IsSystemManaged });
        return genusResults.Concat(taxonResults).OrderBy(r => r.Name).ThenBy(r => r.Kind).ThenBy(r => r.Id);
    }
}

public sealed class NameSearchResult
{
    public int Id { get; init; }
    public string Name { get; init; } = "";
    public string Kind { get; init; } = "";
    public bool IsInactive { get; init; }
    public bool IsPlaceholder { get; init; }
    public string Label => Kind == "genus" ? "Genus" : IsPlaceholder ? "Genus placeholder" : "Species / hybrid";
    public string DetailsPage => Kind == "genus" ? "/Setup/Genera/Details" : "/Setup/Taxa/Details";
}

public sealed record NameSearchPage(IReadOnlyList<NameSearchResult> Results, bool HasMore);
