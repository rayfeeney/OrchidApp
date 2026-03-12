using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Genera;

public class DetailsModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    public Genus? Genus { get; private set; }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        Genus = await _db.Genera
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GenusId == id);

        if (Genus == null)
            return NotFound();

        return Page();
    }
}