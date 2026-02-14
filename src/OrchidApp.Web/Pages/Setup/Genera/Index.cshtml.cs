using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;


namespace OrchidApp.Web.Pages.Setup.Genera;

public class IndexModel : PageModel
{
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
