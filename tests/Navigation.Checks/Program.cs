using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.WebUtilities;
using OrchidApp.Web.Pages.Plants;
using OrchidApp.Web.Services;

var count = 0;
void Check(string name, bool pass) { if (!pass) throw new Exception(name); count++; }
Check("Setup fallback", AppNavigation.Fallback("/Setup/Index", new()) == "/");
foreach (var area in new[] { "Genera", "Taxa", "Locations", "GrowthMedia" })
{
    var root = "/Setup/" + area;
    Check(area + " list fallback", AppNavigation.Fallback(root + "/Index", new()) == "/Setup");
    Check(area + " detail fallback", AppNavigation.Fallback(root + "/Details", new()) == root);
    Check(area + " add fallback", AppNavigation.Fallback(root + "/Actions/Add", new()) == root);
    var key = area == "Locations" ? "locationId" : area == "GrowthMedia" ? "growthMediumId" : "id";
    Check(area + " edit fallback", AppNavigation.Fallback(root + "/Actions/Edit", new() { [key] = 9 }) == root + "/Details/9");
}
foreach (var page in new[] {"/Plants/Events/Add", "/Plants/Events/Edit", "/Plants/Events/Remove", "/Plants/Events/Split", "/Plants/Events/Propagate", "/Plants/Photos/Index", "/Plants/Lineage", "/Plants/Edit/Index"})
    Check(page + " owner fallback", AppNavigation.Fallback(page, new() { ["plantId"] = 42 }) == "/Plants/Details/42");
Check("Plant details direct entry", AppNavigation.Fallback("/Plants/Details", new()) == "/Plants");
foreach (var bad in new string?[] { null, "", " ", "Index", "https://outside.test", "//outside.test", "/\\outside.test", "/%5coutside.test", "/bad\npath", "/%0d%0a" })
    Check("Bad target fallback: " + bad, AppNavigation.Back(bad, "/Setup") == "/Setup");
Check("Query and fragment retained", AppNavigation.Back("/Plants?sort=name#taxon-5", "/") == "/Plants?sort=name#taxon-5");
Check("Canonical self rejected", AppNavigation.Back("/Setup/Locations/Index", "/Setup", "/Setup/Locations") == "/Setup");
Check("Trailing slash self rejected", AppNavigation.Back("/Setup/Locations/", "/Setup", "/Setup/Locations/Index") == "/Setup");
Check("Self wrapper unwrapped", AppNavigation.Back("/Setup/Taxa/Details/9?returnUrl=%2FSetup%2FTaxa%23taxon-9", "/", "/Setup/Taxa/Details/9") == "/Setup/Taxa#taxon-9");
var origin = "/Plants?filter=active&sort=name#taxon-5";
var context = new DefaultHttpContext(); context.Request.Path = "/Plants/Taxon/5";
context.Request.QueryString = new QueryString("?returnUrl=" + Uri.EscapeDataString(origin));
var taxon = new TaxonModel(null!, null!) { PageContext = new PageContext { HttpContext = context } };
var actual = taxon.BuildPlantReturnUrl(42);
var uri = new Uri("http://orchid.test" + actual); var query = QueryHelpers.ParseQuery(uri.Query);
Check("Actual builder roundtrips nested query and fragment", query["returnUrl"] == origin);
Check("Actual builder sets selected plant", query["selectedPlantId"] == "42" && uri.Fragment == "#plant-42");
context.Request.QueryString = new QueryString("?selectedPlantId=3&returnUrl=" + Uri.EscapeDataString(origin));
Check("Selected plant replaced", QueryHelpers.ParseQuery(new Uri("http://orchid.test" + taxon.BuildPlantReturnUrl(42)).Query)["selectedPlantId"] == "42");
var details = AppNavigation.WithReturn("/Plants/Details/42", "/Reports/Repotting");
Check("Event save keeps original details context", AppNavigation.AfterSave(details, "/Plants/Details/42", "/Plants") == details);
Check("New child returns to parent details", AppNavigation.Parent(AppNavigation.AfterSave(details, "/Plants/Details/43", "/Plants")) == details);
var creation = AppNavigation.WithReturn("/Plants/Add", "/Plants?sort=name");
Check("New plant avoids completed add flow", AppNavigation.Parent(AppNavigation.AfterSave(creation, "/Plants/Details/43", "/Plants")) == "/Plants?sort=name");
Check("Genus add shows created details", AppNavigation.Parent(AppNavigation.AfterSave("/Setup/Genera", "/Setup/Genera/Details/9", "/Setup/Genera")) == "/Setup/Genera");
Check("Unsafe save origin default", AppNavigation.Parent(AppNavigation.AfterSave("https://outside.test", "/Setup/Taxa/Details/9", "/Setup/Taxa")) == "/Setup/Taxa");
foreach (var area in new[] { "Locations", "GrowthMedia", "Genera", "Taxa" })
{
    var original = AppNavigation.WithReturn("/Setup/" + area + "/Details/9", "/Setup/" + area + "?filter=active#item-9");
    var saved = original;
    for (var i = 0; i < 25; i++) saved = AppNavigation.AfterSave(saved, "/Setup/" + area + "/Details/9", "/Setup/" + area);
    Check(area + " repeated saves do not grow return chain", saved == original);
}
var filter = new NavigationPageFilter();
foreach (var page in new[] { "/Setup/Index", "/Setup/Locations/Index", "/Setup/GrowthMedia/Index", "/Plants/Details", "/Plants/Photos/Index" })
foreach (var method in new[] { "GET", "POST" })
{
    var http = new DefaultHttpContext(); http.Request.Method = method;
    http.Request.Path = page.EndsWith("/Index") ? page[..^6] : page;
    var routes = new RouteData(); routes.Values["plantId"] = 42;
    var pc = new PageContext(new ActionContext(http, routes,
        new CompiledPageActionDescriptor { ViewEnginePath = page }, new ModelStateDictionary()));
    var model = new NavigationModel { ReturnUrl = "https://outside.test" };
    filter.OnPageHandlerExecuting(new PageHandlerExecutingContext(pc, new List<IFilterMetadata>(), new HandlerMethodDescriptor(), new Dictionary<string, object?>(), model));
    Check(page + method + " before handler", model.ReturnUrl == AppNavigation.Fallback(page, routes.Values));
    pc.ModelState.AddModelError("Name", "Required"); model.ReturnUrl = "//outside.test";
    filter.OnPageHandlerExecuted(new PageHandlerExecutedContext(pc, new List<IFilterMetadata>(), new HandlerMethodDescriptor(), model));
    Check(page + method + " after failed validation", model.ReturnUrl == AppNavigation.Fallback(page, routes.Values) && !pc.ModelState.IsValid);
}
Check("Bounded self traversal", AppNavigation.Back("/Setup?returnUrl=%2FSetup", "/", "/Setup") == "/");
Console.WriteLine($"{count} navigation checks passed.");
sealed class NavigationModel { public string? ReturnUrl { get; set; } }
