using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Infrastructure;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace OrchidApp.Web.Pages.Plants.Events;

public class SplitModel : PageModel
{
    private readonly OrchidDbContext _db;
    private readonly IStoredProcedureExecutor _sp;

    public SplitModel(OrchidDbContext db, IStoredProcedureExecutor sp)
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

    [BindProperty]
    public int ChildCount { get; set; } = 2;

    [BindProperty]
    public List<ChildInput> Children { get; set; } = new();
    public List<SelectListItem> GrowthMedia { get; set; } = new();

    [BindProperty]
    public DateTime SplitDateTime { get; set; }
        = DateTime.Now.AddSeconds(-DateTime.Now.Second)
                      .AddMilliseconds(-DateTime.Now.Millisecond);

    [BindProperty]
    public string? SplitReasonNotes { get; set; }

    [BindProperty]
    public string? SplitNotes { get; set; }

    public class ChildInput
    {
        [Display(Name = "Plant name")]
        public string? PlantName { get; set; }

        [Display(Name = "Growth medium")]
        public int? MediumId { get; set; }
    }

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
    }

    private void EnsureChildListLength()
    {
        if (Children == null)
            Children = new();

        while (Children.Count < ChildCount)
            Children.Add(new ChildInput());
    }

    public async Task<IActionResult> OnGetAsync()
    {
        await LoadPageStateAsync();

        if (EndDate != null)
            return BadRequest("Cannot split an ended plant.");

        if (ChildCount < 2)
            ChildCount = 2;

        Children = Enumerable.Range(0, ChildCount)
            .Select(_ => new ChildInput())
            .ToList();

        return Page();
    }

    public async Task<IActionResult> OnPostAddChildAsync()
    {
        await LoadPageStateAsync();

        if (ChildCount < 2)
            ChildCount = 2;

        ChildCount++;
        EnsureChildListLength();

        ModelState.Clear();
        return Page();
    }

    public async Task<IActionResult> OnPostSplitAsync()
    {
        await LoadPageStateAsync();

        if (IsInactive)
        {
            ModelState.AddModelError(string.Empty,
                "This plant cannot be split because its taxonomy is inactive.");
            EnsureChildListLength();
            return Page();
        }

        if (EndDate != null)
        {
            ModelState.AddModelError(string.Empty,
                "This plant can no longer be split.");
            EnsureChildListLength();
            return Page();
        }

        var splitDate = SplitDateTime.Date;
        // Reconstruct datetime with system time
        var splitDateTime = splitDate.Add(SplitDateTime.TimeOfDay);

        // future
        if (splitDate > DateTime.Today)
        {
            ModelState.AddModelError(nameof(SplitDateTime),
                "Split date cannot be in the future.");
            EnsureChildListLength();
            return Page();
        }

        // before acquisition
        if (AcquisitionDate.HasValue &&
            splitDate < AcquisitionDate.Value.Date)
        {
            ModelState.AddModelError(nameof(SplitDateTime),
                "Split date cannot be before this plant’s lifecycle began.");
            EnsureChildListLength();
            return Page();
        }

        if (ChildCount < 2)
            ChildCount = 2;

        EnsureChildListLength();

        foreach (var c in Children)
        {
            if (c.PlantName != null)
            {
                var name = c.PlantName.Trim();

                if (string.IsNullOrWhiteSpace(name) ||
                    name.Equals("null", StringComparison.OrdinalIgnoreCase))
                {
                    c.PlantName = null;
                }
                else
                {
                    c.PlantName = name;
                }
            }
        }

        var childrenJson = JsonSerializer.Serialize(
            Children.Select(c => new
            {
                plantName = c.PlantName,
                mediumId = c.MediumId
            })
        );

        SplitReasonNotes = string.IsNullOrWhiteSpace(SplitReasonNotes)
            ? null
            : SplitReasonNotes.Trim();

        SplitNotes = string.IsNullOrWhiteSpace(SplitNotes)
            ? null
            : SplitNotes.Trim();

        try
        {
            var createdChildren = await _sp.QueryListAsync<SplitChildResult>(
                "spSplitPlant",
                new StoredProcedureParameter("pParentPlantId", PlantId),
                new StoredProcedureParameter("pSplitDateTime", splitDateTime),
                new StoredProcedureParameter("pChildrenJson", childrenJson),
                new StoredProcedureParameter("pSplitReasonNotes", SplitReasonNotes),
                new StoredProcedureParameter("pSplitNotes", SplitNotes)
            );

            if (createdChildren.Count == 0)
                throw new InvalidOperationException("Split returned no child plants.");

            TempData["SplitChildIdsJson"] = JsonSerializer.Serialize(
                createdChildren.Select(c => c.ChildPlantId).ToList());

            TempData["SplitChildTagsJson"] = JsonSerializer.Serialize(
                createdChildren.Select(c => c.ChildPlantTag).ToList());

            return RedirectToPage(
                "/Plants/Events/SplitConfirmation",
                new { plantId = PlantId }
            );
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
            {
                ModelState.AddModelError(string.Empty, msg);
                EnsureChildListLength();
                return Page();
            }

            throw;
        }
    }
}