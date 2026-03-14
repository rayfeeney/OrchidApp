using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

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
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GrowthMediumId == GrowthMediumId);

        if (entity == null)
            return NotFound();

        Input = entity;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        var entity = await _db.GrowthMedia
            .SingleOrDefaultAsync(g => g.GrowthMediumId == GrowthMediumId);

        if (entity == null)
            return NotFound();

        entity.Name = Input.Name.Trim();
        entity.Description = string.IsNullOrWhiteSpace(Input.Description)
            ? null
            : Input.Description.Trim();

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(
                nameof(Input.Name),
                "A growth medium with this name already exists."
            );
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage(
            "/Setup/GrowthMedia/Details",
            new { growthMediumId = GrowthMediumId }
        );
    }
}