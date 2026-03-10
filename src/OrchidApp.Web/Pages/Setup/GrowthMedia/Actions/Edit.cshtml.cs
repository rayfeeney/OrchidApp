using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Data.Common;

namespace OrchidApp.Web.Pages.Setup.GrowthMedia.Actions;

public class EditModel : PageModel
{
    private readonly OrchidDbContext _db;

    public EditModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int GrowthMediumId { get; set; }

    [BindProperty]
    public GrowthMedium Input { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }
    
    public async Task<IActionResult> OnGetAsync()
    {
        var entity = await _db.GrowthMedia
            .FirstOrDefaultAsync(g => g.GrowthMediumId == GrowthMediumId);

        if (entity == null)
            return NotFound();

        Input = entity;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateGrowthMediumDetails({0}, {1}, {2})",
                GrowthMediumId,
                Input.Name,
                (object?)Input.Description ?? DBNull.Value
            );

            return RedirectToPage("/Setup/GrowthMedia/Details",
                new { growthMediumId = GrowthMediumId });
        }
        catch (DbException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Redirect(ReturnUrl ?? 
                Url.Page("/Setup/GrowthMedia/Details",
                    new { growthMediumId = GrowthMediumId })!);
        }
    }
}