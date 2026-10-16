using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Services;

namespace OrchidApp.Web.Pages.Search;

public class IndexModel(IBotanicalNameSearch search) : PageModel
{
    [BindProperty(SupportsGet = true, Name = "q")]
    public string? SearchText { get; set; }

    [BindProperty(SupportsGet = true)]
    public int ResultsPage { get; set; } = 1;

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public IReadOnlyList<NameSearchResult> Results { get; private set; } = [];
    public bool HasMore { get; private set; }
    public bool HasQuery => !string.IsNullOrWhiteSpace(SearchText);

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        if ((SearchText?.Length ?? 0) > BotanicalNameSearch.MaxQueryLength)
        {
            ModelState.AddModelError(nameof(SearchText), "Use 100 characters or fewer for the name search.");
            return;
        }
        SearchText = BotanicalNameSearch.NormalizeQuery(SearchText);
        ResultsPage = Math.Clamp(ResultsPage, 1, BotanicalNameSearch.MaxPage);
        if (!HasQuery || !ModelState.IsValid) return;
        var result = await search.SearchAsync(SearchText!, ResultsPage, cancellationToken);
        Results = result.Results;
        HasMore = result.HasMore;
    }
}
