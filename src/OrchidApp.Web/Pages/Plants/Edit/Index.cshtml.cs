using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Data.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants.Edit;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    // =========================
    // Route + State
    // =========================

    [BindProperty(SupportsGet = true)]
    public int PlantId { get; set; }

    [BindProperty]
    [Display(Name = "Genus")]
    public int GenusId { get; set; }
    public string? GenusName { get; private set; }

    [BindProperty, Required]
    [Display(Name = "Species / hybrid")]
    public int TaxonId { get; set; }

    public string? SelectedDisplayName { get; private set; }

    public SelectList GenusOptions { get; private set; } = default!;
    public SelectList TaxonOptions { get; private set; } = default!;

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;
    public bool IsEnded => EndDate != null;

    // =========================
    // Editable Fields
    // =========================

    [StringLength(50)]
    [Display(Name = "Plant tag")]
    public string? PlantTag { get; private set; }

    [BindProperty, StringLength(100)]
    [Display(Name = "Plant name")]
    public string? PlantName { get; set; }

    [BindProperty]
    [Display(Name = "Acquired on")]
    public DateTime? AcquisitionDate { get; set; }

    [BindProperty, StringLength(150)]
    [Display(Name = "Acquired from")]
    public string? AcquisitionSource { get; set; }

    [BindProperty]
    [Display(Name = "End date")]
    public DateTime? EndDate { get; set; }

    [BindProperty]
    [Display(Name = "End notes")]
    public string? EndNotes { get; set; }

    [BindProperty]
    [Display(Name = "Plant notes")]
    public string? PlantNotes { get; set; }

    private async Task LoadPlantAsync(int? genusId = null, int? taxonId = null)
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .SingleOrDefaultAsync(p => p.PlantId == PlantId);

        if (plant is null)
            throw new InvalidOperationException("Plant not found");

        PlantTag = plant.PlantTag;
        PlantName = plant.PlantName;
        AcquisitionDate = plant.AcquisitionDate;
        AcquisitionSource = plant.AcquisitionSource;
        EndDate = plant.EndDate;
        EndNotes = plant.EndNotes;
        PlantNotes = plant.PlantNotes;

        int effectiveTaxonId = plant.TaxonId;

        if (taxonId.HasValue)
            effectiveTaxonId = taxonId.Value;
        else if (genusId.HasValue)
        {
            effectiveTaxonId = await _db.TaxonIdentities
                .Where(t => t.GenusId == genusId.Value && t.IsSystemManaged)
                .Select(t => t.TaxonId)
                .FirstAsync();
        }

        TaxonId = effectiveTaxonId;

        var selected = await _db.TaxonIdentities
            .AsNoTracking()
            .SingleAsync(t => t.TaxonId == TaxonId);

        GenusId = selected.GenusId;
        GenusName = selected.GenusName;
        SelectedDisplayName = selected.DisplayName;

        GenusIsActive = selected.GenusIsActive;
        TaxonIsActive = selected.TaxonIsActive;

        await LoadGenusOptionsAsync();
        await LoadTaxonOptionsAsync();
    }

    // =========================
    // GET
    // =========================

    public async Task<IActionResult> OnGetAsync(int? genusId, int? taxonId)
    {
        try
        {
            await LoadPlantAsync(genusId, taxonId);
            return Page();
        }
        catch (InvalidOperationException)
        {
            return NotFound();
        }
    }

    // =========================
    // SAVE
    // =========================

    public async Task<IActionResult> OnPostAsync()
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantId == PlantId)
            .Select(p => new { p.EndDate })
            .SingleAsync();

        if (plant.EndDate != null)
            return BadRequest();

        if (!ModelState.IsValid)
        {
            await LoadPlantAsync(GenusId, TaxonId);
            return Page();
        }

        try
        {
            await CallSpUpdatePlantDetailsAsync();
        }
        catch (DbException ex)
        {
            ModelState.AddModelError(string.Empty, ex.GetBaseException().Message);
            await LoadPlantAsync(GenusId, TaxonId);
            return Page();
        }

        return RedirectToPage("/Plants/Taxon", new
        {
            taxonId = TaxonId
        });
    }

    // =========================
    // GENUS CHANGE
    // =========================

    public async Task<IActionResult> OnPostGenusChanged()
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantId == PlantId)
            .Select(p => new { p.EndDate })
            .SingleAsync();

        if (plant.EndDate != null)
            return BadRequest();

        return RedirectToPage(new
        {
            plantId = PlantId,
            genusId = GenusId
        });
    }

    // =========================
    // TAXON CHANGE
    // =========================

    public async Task<IActionResult> OnPostTaxonChanged()
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantId == PlantId)
            .Select(p => new { p.EndDate })
            .SingleAsync();

        if (plant.EndDate != null)
            return BadRequest();

        return RedirectToPage(new
        {
            plantId = PlantId,
            taxonId = TaxonId
        });
    }

    // =========================
    // Option Loaders
    // =========================

    private async Task LoadGenusOptionsAsync()
    {
        var genera = await _db.Genera
            .AsNoTracking()
            .Where(g => g.IsActive || g.GenusId == GenusId)
            .OrderBy(g => g.Name)
            .Select(g => new
            {
                g.GenusId,
                g.Name,
                g.IsActive
            })
            .ToListAsync();

        GenusOptions = new SelectList(
            genera.Select(g => new
            {
                g.GenusId,
                Name = g.IsActive ? g.Name : g.Name + " (inactive)"
            }),
            "GenusId",
            "Name",
            GenusId
        );
    }

    private async Task LoadTaxonOptionsAsync()
    {
        var taxa = await _db.TaxonIdentities
            .AsNoTracking()
            .Where(t =>
                t.GenusId == GenusId &&
                (t.TaxonIsActive || t.TaxonId == TaxonId))
            .OrderByDescending(t => t.IsSystemManaged)
            .ThenBy(t => t.DisplayName)
            .ToListAsync();

        var selected = taxa.FirstOrDefault(t => t.TaxonId == TaxonId);

        SelectedDisplayName = selected?.DisplayName ?? "Unknown";

        TaxonOptions = new SelectList(
            taxa.Select(t => new
            {
                t.TaxonId,
                Name = t.TaxonIsActive
                    ? (t.IsSystemManaged ? "sp." : t.DisplayName)
                    : (t.IsSystemManaged ? "sp. (inactive)" : t.DisplayName + " (inactive)")
            }),
            "TaxonId",
            "Name",
            TaxonId
        );
    }

    // =========================
    // SP Call
    // =========================

    private async Task CallSpUpdatePlantDetailsAsync()
    {
        var parameters = new object?[]
        {
            PlantId,
            TaxonId,
            PlantName,
            AcquisitionDate,
            AcquisitionSource,
            EndDate,
            EndNotes,
            PlantNotes
        };

        await _db.Database.ExecuteSqlRawAsync(
            @"CALL spUpdatePlantDetails(
                {0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}
            );",
            parameters!);
    }
}