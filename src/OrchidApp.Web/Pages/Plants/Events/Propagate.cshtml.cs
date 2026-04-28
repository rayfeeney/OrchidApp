using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Infrastructure;
using Microsoft.AspNetCore.Mvc.Rendering;
using OrchidApp.Web.Models.Lookups;

namespace OrchidApp.Web.Pages.Plants.Events;

public class PropagateModel : PageModel
{
    private readonly OrchidDbContext _db;
    private readonly IStoredProcedureExecutor _sp;

    public PropagateModel(OrchidDbContext db, IStoredProcedureExecutor sp)
    {
        _db = db;
        _sp = sp;
    }

    [FromRoute]
    public int PlantId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public DateTime? AcquisitionDate { get; private set; }
    public DateTime? EndDate { get; private set; }

    public PlantCurrentLocation? Plant { get; private set; }

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }

    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    public List<SelectListItem> GrowthMedia { get; set; } = new();
    public List<SelectListItem> PropagationTypes { get; set; } = new();

    [BindProperty]
    [Display(Name = "Propagation type")]
    public int PropagationTypeId { get; set; }

    [BindProperty]
    [Display(Name = "Propagation date")]
    public DateTime PropagationDate { get; set; } = DateTime.Today;

    [BindProperty]
    [Display(Name = "Plant name")]
    public string? PlantName { get; set; }

    [BindProperty]
    [Display(Name = "Growth medium")]
    public int? MediumId { get; set; }

    [BindProperty]
    [Display(Name = "Notes")]
    public string? PropagationNotes { get; set; }

    private async Task LoadPageStateAsync()
    {
        var lifecycle = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantId == PlantId)
            .Select(p => new
            {
                p.AcquisitionDate,
                p.EndDate
            })
            .SingleAsync();

        AcquisitionDate = lifecycle.AcquisitionDate;
        EndDate = lifecycle.EndDate;

        Plant = await _db.PlantCurrentLocations
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (Plant == null)
            throw new InvalidOperationException("Plant not found.");

        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == Plant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .SingleAsync();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        GrowthMedia = await _db.GrowthMedia
            .AsNoTracking()
            .Where(m => m.IsActive)
            .OrderBy(m => m.Name)
            .Select(m => new SelectListItem
            {
                Value = m.GrowthMediumId.ToString(),
                Text = m.Name
            })
            .ToListAsync();

        PropagationTypes = await _db.Set<PropagationTypeLookup>()
            .FromSqlRaw(@"
                SELECT propagationTypeId, propagationTypeName
                FROM propagationtype
                WHERE isActive = 1")
            .AsNoTracking()
            .Select(p => new SelectListItem
            {
                Value = p.PropagationTypeId.ToString(),
                Text = p.PropagationTypeName
            })
            .ToListAsync();
    }

    public async Task<IActionResult> OnGetAsync()
    {
        await LoadPageStateAsync();

        if (EndDate != null)
            return BadRequest("Cannot propagate an ended plant.");

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        await LoadPageStateAsync();

        if (IsInactive)
        {
            ModelState.AddModelError(string.Empty,
                "This plant cannot be propagated because its taxonomy is inactive.");
            return Page();
        }

        if (EndDate != null)
        {
            ModelState.AddModelError(string.Empty,
                "This plant can no longer be propagated.");
            return Page();
        }

        var propagationDate = PropagationDate.Date;

        // future
        if (propagationDate > DateTime.Today)
        {
            ModelState.AddModelError(nameof(PropagationDate),
                "Propagation date cannot be in the future.");
            return Page();
        }

        // before acquisition
        if (AcquisitionDate.HasValue &&
            propagationDate < AcquisitionDate.Value.Date)
        {
            ModelState.AddModelError(nameof(PropagationDate),
                "Propagation date cannot be before this plant’s lifecycle began.");
            return Page();
        }

        if (PropagationTypeId == 0)
        {
            ModelState.AddModelError(nameof(PropagationTypeId),
                "Propagation type is required.");
            return Page();
        }

        if (PlantName != null)
        {
            var name = PlantName.Trim();

            PlantName = string.IsNullOrWhiteSpace(name) ||
                        name.Equals("null", StringComparison.OrdinalIgnoreCase)
                ? null
                : name;
        }

        PropagationNotes = string.IsNullOrWhiteSpace(PropagationNotes)
            ? null
            : PropagationNotes.Trim();

        try
        {
            var result = await _sp.QuerySingleAsync<PropagateResult>(
                "spPropagatePlant",
                new StoredProcedureParameter("pParentPlantId", PlantId),
                new StoredProcedureParameter("pPropagationDate", propagationDate),
                new StoredProcedureParameter("pPropagationTypeId", PropagationTypeId),
                new StoredProcedureParameter("pChildPlantName", PlantName),
                new StoredProcedureParameter("pMediumId", MediumId),
                new StoredProcedureParameter("pPropagationNotes", PropagationNotes)
            );

            TempData["PropagationChildId"] = result.ChildPlantId.ToString();
            TempData["PropagationChildTag"] = result.ChildPlantTag;

            return RedirectToPage(
                "/Plants/Events/PropagateConfirmation",
                new { plantId = PlantId }
            );
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
            {
                ModelState.AddModelError(string.Empty, msg);
                return Page();
            }

            throw;
        }
    }
}

public class PropagateResult
{
    public int ChildPlantId { get; set; }
    public string ChildPlantTag { get; set; } = "";
}
