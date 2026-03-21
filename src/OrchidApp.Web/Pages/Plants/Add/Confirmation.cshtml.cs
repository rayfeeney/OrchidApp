using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants.Add;

public class ConfirmationModel : PageModel
{
    private readonly OrchidDbContext _db;

    public ConfirmationModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public PlantActiveSummary? Plant { get; private set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Plant = await _db.PlantActiveSummaries
            .Where(p => p.PlantId == PlantId)
            .SingleOrDefaultAsync();

        if (Plant == null)
        {
            return NotFound();
        }

        if (!Plant.GenusIsActive || !Plant.TaxonIsActive)
        {
            return NotFound();
        }

        return Page();
    }

    public IActionResult OnPostContinue()
    {
        return RedirectToPage(
            "/Plants/Details",
            new { plantId = PlantId }
        );
    }
}