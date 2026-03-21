using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Infrastructure;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Plants.Add;

[BindProperties]
public class CreateModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    private readonly IStoredProcedureExecutor _spExecutor;

    public CreateModel(
        OrchidDbContext db,
        IStoredProcedureExecutor spExecutor)
    {
        _db = db;
        _spExecutor = spExecutor;
    }

    [FromRoute]
    public int TaxonId { get; set; }

    public TaxonIdentity? Taxon { get; private set; }

    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [StringLength(100)]
        [Display(Name = "Plant name")]
        public string? PlantName { get; set; }

        [DataType(DataType.Date)]
        [Display(Name = "Acquired on")]
        public DateTime? AcquisitionDate { get; set; }

        [StringLength(150)]
        [Display(Name = "Acquired from")]
        public string? AcquisitionSource { get; set; }

        [Display(Name = "Plant notes")]
        public string? PlantNotes { get; set; }
    }

    public async Task<IActionResult> OnGetAsync()
    {
        Taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == TaxonId
                    && t.TaxonIsActive
                    && t.GenusIsActive)
            .SingleOrDefaultAsync();

        if (Taxon == null)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        Taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == TaxonId
                    && t.TaxonIsActive
                    && t.GenusIsActive)
            .SingleOrDefaultAsync();

        if (Taxon == null)
            return NotFound();

        if (!ModelState.IsValid)
            return Page();

        int plantId;

        try
        {
            var result = await _spExecutor.QuerySingleAsync<AddPlantResult>(
                "spAddPlant",
                new StoredProcedureParameter("pTaxonId", TaxonId),
                new StoredProcedureParameter("pDate", Input.AcquisitionDate),
                new StoredProcedureParameter("pSource", Input.AcquisitionSource),
                new StoredProcedureParameter("pName", Input.PlantName),
                new StoredProcedureParameter("pNotes", Input.PlantNotes)
            );

            plantId = result.PlantId;
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

        return RedirectToPage(
            "/Plants/Add/Confirmation",
            new { plantId }
        );
    }
}