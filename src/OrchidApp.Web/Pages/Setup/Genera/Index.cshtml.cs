using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace OrchidApp.Web.Pages.Setup.Genera;

public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public List<Genus> Genera { get; private set; } = [];

    public void OnGet()
    {
        Genera = _db.Genera
                    .OrderBy(g => g.Name)
                    .ToList();
    }

}
