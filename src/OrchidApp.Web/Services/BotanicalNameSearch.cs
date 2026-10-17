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
        page = Math.Clamp(page, 1, MaxPage);
        var names = BuildQuery(db.Genera.AsNoTracking(), db.TaxonIdentities.AsNoTracking(), query);
        var plants = BuildPlantQuery(db.Plants.AsNoTracking(), db.PlantActiveCurrentLocations.AsNoTracking(), query);
        var results = new List<NameSearchResult>();
        var hasMore = false;
        // Page each category separately so all matching categories can appear.
        // Execute sequentially: one DbContext cannot run concurrent queries.
        foreach (var category in new[] { names.Where(r => r.Kind == "genus"), names.Where(r => r.Kind == "taxon"), plants })
        {
            var rows = await category.Skip((page - 1) * PageSize).Take(PageSize + 1).ToListAsync(cancellationToken);
            results.AddRange(rows.Take(PageSize));
            hasMore |= rows.Count > PageSize && page < MaxPage;
        }
        return new(results, hasMore);
    }

    public static IQueryable<Plant> ActivePlants(IQueryable<Plant> plants) =>
        plants.Where(p => p.IsActive && p.EndDate == null);

    public static IQueryable<NameSearchResult> BuildPlantQuery(
        IQueryable<Plant> plants, IQueryable<PlantActiveCurrentLocation> identities, string text)
    {
        var candidates = from plant in ActivePlants(plants)
                         join identity in identities on plant.PlantId equals identity.PlantId
                         select identity;
        foreach (var term in NormalizeQuery(text).Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            candidates = candidates.Where(p =>
                EF.Functions.Collate(p.DisplayName + " " + (p.PlantTag ?? "") + " " + (p.PlantName ?? ""), NameCollation).Contains(term));
        }
        return candidates.Select(p => new NameSearchResult {
            Id = p.PlantId, Name = EF.Functions.Collate(p.DisplayName, NameCollation), Kind = "plant",
            PlantTag = p.PlantTag, PlantName = p.PlantName, LocationName = p.LocationName,
            IsInactive = false, IsPlaceholder = false
        }).OrderBy(r => r.Name).ThenBy(r => r.PlantTag).ThenBy(r => r.Id);
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
    public string? PlantTag { get; init; }
    public string? PlantName { get; init; }
    public string? LocationName { get; init; }
    public string Label => Kind == "plant" ? "Plant" : Kind == "genus" ? "Genus" : IsPlaceholder ? "Genus placeholder" : "Species / hybrid";
    public string DetailsPage => Kind == "plant" ? "/Plants/Details" : Kind == "genus" ? "/Setup/Genera/Details" : "/Setup/Taxa/Details";
    public Dictionary<string, string> DetailsRouteValues => new() {
        [Kind == "plant" ? "plantId" : "id"] = Id.ToString(System.Globalization.CultureInfo.InvariantCulture)
    };
}

public sealed record NameSearchPage(IReadOnlyList<NameSearchResult> Results, bool HasMore);
