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
    [FromRoute]
    public int Id { get; set; }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        Genus = await _db.Genera
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GenusId == id);

        if (Genus == null)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostToggleActiveAsync()
    {
        var current = await _db.Genera
            .AsNoTracking()
            .Where(g => g.GenusId == Id)
            .Select(g => (bool?)g.IsActive)
            .SingleOrDefaultAsync();

        if (current == null)
            return NotFound();

        await _db.Database.ExecuteSqlRawAsync(
            "CALL spSetGenusActiveState({0},{1})",
            Id,
            current.Value ? 0 : 1
        );

        return RedirectToPage(new { Id, ReturnUrl });
    }
}