using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
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

    public IActionResult OnGet()
    {
        var location = _db.Locations
                          .AsNoTracking()
                          .FirstOrDefault(l => l.LocationId == LocationId)
                       ?? throw new InvalidOperationException("Location not found.");

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

    public IActionResult OnPost()
    {
        if (!ModelState.IsValid)
            return Page();

        _db.Database.ExecuteSqlRaw(
            "CALL spUpdateLocation({0},{1},{2},{3},{4},{5},{6})",
            LocationId,
            Input.LocationName,
            Input.LocationTypeCode,
            Input.LocationNotes,
            Input.ClimateCode,
            Input.ClimateNotes,
            Input.LocationGeneralNotes
        );

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Locations/Details", new { locationId = LocationId })!);
    }
}