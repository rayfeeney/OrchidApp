using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class EditModel : PageModel
{
    private readonly OrchidDbContext _db;

    public EditModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty]
    public Genus Genus { get; set; } = null!;

    public IActionResult OnGet(int id)
    {
        var genus = _db.Genera.SingleOrDefault(g => g.GenusId == id);

        if (genus == null)
            return NotFound();

        Genus = genus;

        return Page();
    }

    public IActionResult OnPost(int id)
    {
        var existing = _db.Genera.SingleOrDefault(g => g.GenusId == id);

        if (existing == null)
            return NotFound();

        existing.Name = Genus.Name;
        existing.Notes = Genus.Notes;

        _db.SaveChanges();

        return RedirectToPage("/Setup/Genera/Details", new { id = existing.GenusId });
    }
}
