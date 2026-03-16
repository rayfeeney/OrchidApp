using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Infrastructure;
using System;

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
    public bool IsActive { get; private set; }

    [BindProperty]
    public GrowthMedium Input { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        var entity = await _db.GrowthMedia
            .AsNoTracking()
            .Where(g => g.GrowthMediumId == GrowthMediumId)
            .Select(g => new
            {
                Entity = g,
                g.IsActive
            })
            .SingleOrDefaultAsync();

        if (entity == null)
            return NotFound();

        Input = entity.Entity;
        IsActive = entity.IsActive;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        try
        {
            object descriptionParam =
                string.IsNullOrWhiteSpace(Input.Description)
                    ? DBNull.Value
                    : Input.Description.Trim();

            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateGrowthMediumDetails({0},{1},{2})",
                new object[]
                {
                    GrowthMediumId,
                    Input.Name.Trim(),
                    descriptionParam
                });
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var message))
            {
                ModelState.AddModelError(nameof(Input.Name), message);
                return Page();
            }

            throw;
        }

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage(
            "/Setup/GrowthMedia/Details",
            new { growthMediumId = GrowthMediumId }
        );
    }
}