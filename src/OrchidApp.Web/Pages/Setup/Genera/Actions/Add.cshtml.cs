using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.ComponentModel.DataAnnotations;
using System.Data.Common;
using OrchidApp.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty, Required]
    public string GenusName { get; set; } = string.Empty;

    [BindProperty]
    public string? GenusNotes { get; set; }

    public IActionResult OnGet()
    {
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        try
        {
            await _db.Database.ExecuteSqlInterpolatedAsync($@"
                CALL spAddGenus(
                    {GenusName},
                    {GenusNotes},
                    @pGenusId,
                    @pGenusOnlyTaxonId
                );
            ");

            return RedirectToPage("/Setup/Genera/Index");
        }
        catch (DbException ex)
        {
            ModelState.AddModelError(
                string.Empty,
                $"Unable to save the genus. {ex.Message}"
            );

            return Page();
        }
    }
}
