using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Genera;

public class DetailsModel : PageModel
{
    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    public Genus? Genus { get; private set; }

    public IActionResult OnGet(int id)
    {
        Genus = _db.Genera
                .SingleOrDefault(g => g.GenusId == id && g.IsActive);

        if (Genus == null)
        {
            return NotFound();
        }

        return Page();
    }

}
