using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using System.ComponentModel.DataAnnotations;
using MySqlConnector;
using System.Data.Common;


namespace OrchidApp.Web.Pages.Setup.Taxa.Actions;

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    public List<GenusLookup> Genera { get; private set; } = [];

    [BindProperty, Required]
    public int GenusId { get; set; }

    [BindProperty]
    public string? SpeciesName { get; set; }

    [BindProperty]
    public string? HybridName { get; set; }

    [BindProperty]
    public string? GrowthNotes { get; set; }

    [BindProperty]
    public string? TaxonNotes { get; set; }

    public async Task OnGetAsync()
    {
        Genera = await _db.Genera
            .Where(g => g.IsActive)
            .OrderBy(g => g.Name)
            .Select(g => new GenusLookup
            {
                GenusId = g.GenusId,
                GenusName = g.Name
            })
            .ToListAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            await OnGetAsync();
            return Page();
        }

        try
        {
            await _db.Database.ExecuteSqlInterpolatedAsync($@"
                CALL spAddTaxon(
                    {GenusId},
                    {SpeciesName},
                    {HybridName},
                    {GrowthNotes},
                    {TaxonNotes}
                );
            ");

            return RedirectToPage("/Setup/Taxa/Index");
        }
        catch (MySqlException ex)
        {
            // This is where SIGNAL SQLSTATE '45000' ends up
            ModelState.AddModelError(string.Empty, ex.Message);
            await OnGetAsync();
            return Page();
        }
        catch (DbException ex)
        {
            // Fallback for other DB providers / unexpected DB errors
            ModelState.AddModelError(string.Empty, $"Unable to save the species/hybrid. {ex.Message}");
            await OnGetAsync();
            return Page();
        }
    }

    public class GenusLookup
    {
        public int GenusId { get; set; }
        public string GenusName { get; set; } = "";
    }
}
