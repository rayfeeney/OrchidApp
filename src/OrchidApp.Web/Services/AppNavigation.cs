using Microsoft.AspNetCore.WebUtilities;
using Microsoft.AspNetCore.Routing;

namespace OrchidApp.Web.Services;

public static class AppNavigation
{
    public static bool IsLocal(string? url) => !string.IsNullOrWhiteSpace(url)
        && url.Length <= 16000 && url[0] == '/' && (url.Length == 1 || url[1] is not '/' and not '\\')
        && !url.Any(c => char.IsControl(c) || c == '\\')
        && !url.Contains("%5c", StringComparison.OrdinalIgnoreCase)
        && !url.Contains("%0d", StringComparison.OrdinalIgnoreCase)
        && !url.Contains("%0a", StringComparison.OrdinalIgnoreCase);

    public static string Path(string url)
    {
        var path = url.Split('?', '#')[0].TrimEnd('/');
        if (path.EndsWith("/Index", StringComparison.OrdinalIgnoreCase)) path = path[..^6];
        return path.Length == 0 ? "/" : path;
    }

    public static string? Parent(string url)
    {
        var query = url.Split('#')[0];
        var start = query.IndexOf('?');
        return start < 0 ? null : QueryHelpers.ParseQuery(query[start..])
            .FirstOrDefault(p => p.Key.Equals("returnUrl", StringComparison.OrdinalIgnoreCase)).Value.FirstOrDefault();
    }

    public static string Back(string? candidate, string fallback, string? current = null)
    {
        for (var depth = 0; depth < 12 && IsLocal(candidate); depth++)
        {
            if (current == null || !Path(candidate!).Equals(Path(current), StringComparison.OrdinalIgnoreCase))
                return candidate!;
            candidate = Parent(candidate!);
        }
        return IsLocal(fallback) ? fallback : "/";
    }

    public static string WithReturn(string target, string? origin, string fallback = "/Plants") =>
        QueryHelpers.AddQueryString(target, "returnUrl", Back(origin, fallback, target));

    // Keep an existing details address intact, including its own return context.
    // A newly created record instead links back to a deliberate view/list page.
    public static string AfterSave(string? origin, string details, string fallback)
    {
        origin = Back(origin, fallback);
        for (var depth = 0; depth < 12 && IsEntryForm(origin); depth++)
            origin = Back(Parent(origin), fallback, origin);
        if (IsEntryForm(origin)) origin = fallback;
        if (Path(origin).Equals(Path(details), StringComparison.OrdinalIgnoreCase)) return origin;
        return WithReturn(details, origin, fallback);
    }

    private static bool IsEntryForm(string url)
    {
        var path = Path(url);
        return path.Contains("/Actions/", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/Plants/Add", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/Plants/Edit", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/Plants/Events/", StringComparison.OrdinalIgnoreCase);
    }

    public static string Fallback(string page, RouteValueDictionary routes)
    {
        string Detail(string prefix, string key) => routes.TryGetValue(key, out var id)
            && int.TryParse(id?.ToString(), out var value) && value > 0 ? prefix + "/" + value : "/Plants";
        if (page == "/Setup/Index") return "/";
        foreach (var area in new[] { "Genera", "Taxa", "Locations", "GrowthMedia" })
        {
            var root = "/Setup/" + area;
            if (page == root + "/Index") return "/Setup";
            if (page == root + "/Actions/Edit")
            {
                var key = area == "Locations" ? "locationId" : area == "GrowthMedia" ? "growthMediumId" : "id";
                var detail = Detail(root + "/Details", key);
                return detail == "/Plants" ? root : detail;
            }
            if (page.StartsWith(root + "/", StringComparison.OrdinalIgnoreCase)) return root;
        }
        if (page == "/Plants/Index") return "/";
        if (page == "/Plants/Details" || page == "/Plants/Taxon" || page.Contains("Confirmation")) return "/Plants";
        if (page == "/Plants/Add/Create") return "/Plants/Add";
        if (page == "/Plants/Add/Index") return "/Plants";
        if (page.StartsWith("/Plants/")) return Detail("/Plants/Details", "plantId");
        if (page == "/Reports/Index") return "/";
        if (page.StartsWith("/Reports/")) return "/Reports";
        return "/";
    }

    public static string Label(string url) => Path(url) switch
    {
        "/" => "Back to home",
        "/Setup" => "Back to setup",
        "/Setup/Genera" => "Back to genus list",
        "/Setup/Taxa" => "Back to species / hybrids",
        "/Setup/Locations" => "Back to locations",
        "/Setup/GrowthMedia" => "Back to growth media",
        "/Plants" => "Back to plants",
        "/Plants/Add" => "Back to plant selection",
        "/Reports" => "Back to reports",
        "/Reports/Repotting" => "Back to repotting report",
        "/Reports/Flowering" => "Back to flowering report",
        "/Reports/FloweringHistory" => "Back to flowering history",
        var p when p.StartsWith("/Plants/Details/") => "Back to plant details",
        var p when p.StartsWith("/Plants/Taxon/") => "Back to plant list",
        var p when p.StartsWith("/Plants/Lineage/") => "Back to lineage",
        var p when p.Contains("/Details/") => "Back to details",
        _ => "Back"
    };
}
