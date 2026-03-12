using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class EditModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;
    private readonly IStoredProcedureExecutor _sp;

    public EditModel(OrchidDbContext db, IStoredProcedureExecutor sp)
    {
        _db = db;
        _sp = sp;
    }

    [BindProperty]
    public Genus Genus { get; set; } = null!;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var genus = await _db.Genera
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GenusId == id);

        if (genus == null)
            return NotFound();

        Genus = genus;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(int id)
    {
        if (!ModelState.IsValid)
            return Page();

        var result = await _sp.QuerySingleAsync<AddGenusResult>(
            "CALL spUpdateGenus(@p0, @p1, @p2);",
            id,
            Genus.Name,
            Genus.Notes
        );

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage("/Setup/Genera/Details", new { id = result.GenusId });
    }
}