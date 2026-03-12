using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

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

    public async Task OnGetAsync()
    {
        Genera = await _db.Genera
            .AsNoTracking()
            .OrderBy(g => g.Name)
            .ToListAsync();
    }
}
