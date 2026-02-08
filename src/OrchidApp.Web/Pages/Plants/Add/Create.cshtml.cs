using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Plants.Add;

[BindProperties]
public class CreateModel : PageModel
{
    private readonly OrchidDbContext _db;

    public CreateModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int TaxonId { get; set; }

    public TaxonIdentity? Taxon { get; private set; }

    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required(ErrorMessage = "Plant tag is required.")]
        [StringLength(50)]
        [Display(Name = "Plant tag")]
        public string? PlantTag { get; set; }

        [StringLength(100)]
        [Display(Name = "Plant name")]
        public string? PlantName { get; set; }

        [DataType(DataType.Date)]
        [Display(Name = "Acquired on")]
        public DateOnly? AcquisitionDate { get; set; }

        [StringLength(150)]
        [Display(Name = "Acquired from")]
        public string? AcquisitionSource { get; set; }

        [Display(Name = "Plant notes")]
        public string? PlantNotes { get; set; }
    }

    public async Task<IActionResult> OnGetAsync()
    {
        Taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == TaxonId && t.IsActive)
            .SingleOrDefaultAsync();

        if (Taxon == null)
        {
            return NotFound();
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        Taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == TaxonId && t.IsActive)
            .SingleOrDefaultAsync();

        if (Taxon == null)
        {
            return NotFound();
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        var plant = new Plant
        {
            TaxonId = TaxonId,
            PlantTag = string.IsNullOrWhiteSpace(Input.PlantTag)
                            ? null
                            : Input.PlantTag.Trim(),
            PlantName = Input.PlantName,
            AcquisitionDate = Input.AcquisitionDate,
            AcquisitionSource = Input.AcquisitionSource,
            PlantNotes = Input.PlantNotes,
            IsActive = true
        };

        _db.Plants.Add(plant);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(
                nameof(Input.PlantTag),
                "This plant tag is already in use."
            );
            return Page();
        }

        return RedirectToPage(
            "/Plants/Details",
            new { plantId = plant.PlantId }
        );
    }
}
