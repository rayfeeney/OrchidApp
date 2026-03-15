using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Setup.Locations.Actions;

public class EditModel : PageModel
{
    private readonly OrchidDbContext _db;

    public EditModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int LocationId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }
    public bool IsActive { get; private set; }
    public bool IsInactive => !IsActive;

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required]
        [Display(Name = "Location name")]
        public string LocationName { get; set; } = "";

        [Display(Name = "Location type")]
        public string? LocationTypeCode { get; set; }

        [Display(Name = "Location notes")]
        public string? LocationNotes { get; set; }

        [Display(Name = "Climate")]
        public string? ClimateCode { get; set; }

        [Display(Name = "Climate notes")]
        public string? ClimateNotes { get; set; }

        [Display(Name = "General notes")]
        public string? LocationGeneralNotes { get; set; }
    }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        var location = await _db.Locations
            .AsNoTracking()
            .FirstOrDefaultAsync(l => l.LocationId == LocationId, ct);

        if (location == null)
            return NotFound();

        IsActive = location.IsActive;

        Input = new InputModel
        {
            LocationName = location.LocationName,
            LocationTypeCode = location.LocationTypeCode,
            LocationNotes = location.LocationNotes,
            ClimateCode = location.ClimateCode,
            ClimateNotes = location.ClimateNotes,
            LocationGeneralNotes = location.LocationGeneralNotes
        };

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return Page();

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateLocationDetails({0},{1},{2},{3},{4},{5},{6})",
                (object?)LocationId!,
                (object?)Input.LocationName!,
                (object?)Input.LocationTypeCode!,
                (object?)Input.LocationNotes!,
                (object?)Input.ClimateCode!,
                (object?)Input.ClimateNotes!,
                (object?)Input.LocationGeneralNotes!
            );
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var message))
            {
                ModelState.AddModelError(string.Empty, message);
                return Page();
            }

            throw;
        }

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Locations/Details", new { locationId = LocationId })!);
    }
}
