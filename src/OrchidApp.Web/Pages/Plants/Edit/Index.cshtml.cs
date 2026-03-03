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

    [BindProperty, Required]
    [Display(Name = "Species / hybrid")]
    public int TaxonId { get; set; }

    public string? SelectedDisplayName { get; private set; }

    public SelectList GenusOptions { get; private set; } = default!;
    public SelectList TaxonOptions { get; private set; } = default!;

    // =========================
    // Editable Fields
    // =========================

    [BindProperty, StringLength(50)]
    [Display(Name = "Plant tag")]
    public string? PlantTag { get; set; }

    [BindProperty, StringLength(100)]
    [Display(Name = "Plant name")]
    public string? PlantName { get; set; }

    [BindProperty, Required]
    [Display(Name = "Acquired on")]
    public DateTime AcquisitionDate { get; set; }

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

    // =========================
    // GET
    // =========================

    public async Task<IActionResult> OnGetAsync(int? genusId, int? taxonId)
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .SingleOrDefaultAsync(p => p.PlantId == PlantId);

        if (plant is null)
            return NotFound();

        // Always load plant fields from DB
        PlantTag = plant.PlantTag;
        PlantName = plant.PlantName;
        AcquisitionDate = plant.AcquisitionDate ?? DateTime.Now;
        AcquisitionSource = plant.AcquisitionSource;
        EndDate = plant.EndDate;
        EndNotes = plant.EndNotes;
        PlantNotes = plant.PlantNotes;

        // Determine effective selection
        int effectiveTaxonId = plant.TaxonId;

        if (taxonId.HasValue)
        {
            effectiveTaxonId = taxonId.Value;
        }
        else if (genusId.HasValue)
        {
            effectiveTaxonId = await _db.TaxonIdentities
                .AsNoTracking()
                .Where(t =>
                    t.GenusId == genusId.Value &&
                    t.IsActive &&
                    t.IsSystemManaged)
                .Select(t => t.TaxonId)
                .SingleAsync();
        }

        TaxonId = effectiveTaxonId;

        var selected = await _db.TaxonIdentities
            .AsNoTracking()
            .SingleAsync(t => t.TaxonId == TaxonId);

        GenusId = selected.GenusId;
        SelectedDisplayName = selected.DisplayName;

        await LoadGenusOptionsAsync();
        await LoadTaxonOptionsAsync();

        return Page();
    }

    // =========================
    // SAVE
    // =========================

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            await LoadGenusOptionsAsync();
            await LoadTaxonOptionsAsync();
            return Page();
        }

        try
        {
            await CallSpUpdatePlantDetailsAsync();
        }
        catch (DbException ex)
        {
            ModelState.AddModelError(string.Empty, ex.GetBaseException().Message);
            await LoadGenusOptionsAsync();
            await LoadTaxonOptionsAsync();
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

    public IActionResult OnPostGenusChanged()
    {
        return RedirectToPage(new
        {
            plantId = PlantId,
            genusId = GenusId
        });
    }

    // =========================
    // TAXON CHANGE
    // =========================

    public IActionResult OnPostTaxonChanged()
    {
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
            .Where(g => g.IsActive)
            .OrderBy(g => g.Name)
            .Select(g => new { g.GenusId, g.Name })
            .ToListAsync();

        GenusOptions = new SelectList(genera, "GenusId", "Name", GenusId);
    }

    private async Task LoadTaxonOptionsAsync()
    {
        var taxa = await _db.TaxonIdentities
            .AsNoTracking()
            .Where(t => t.GenusId == GenusId && t.IsActive)
            .OrderByDescending(t => t.IsSystemManaged)
            .ThenBy(t => t.DisplayName)
            .ToListAsync();

        SelectedDisplayName = taxa
            .First(t => t.TaxonId == TaxonId)
            .DisplayName;

        TaxonOptions = new SelectList(
            taxa.Select(t => new
            {
                t.TaxonId,
                Name = t.IsSystemManaged
                    ? "sp."
                    : t.SpeciesName ?? t.HybridName
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
        var conn = _db.Database.GetDbConnection();

        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandType = CommandType.Text;
        cmd.CommandText =
            "CALL spUpdatePlantDetails(" +
            "  @pPlantId," +
            "  @pTaxonId," +
            "  @pPlantTag," +
            "  @pPlantName," +
            "  @pAcquisitionDate," +
            "  @pAcquisitionSource," +
            "  @pEndDate," +
            "  @pEndNotes," +
            "  @pPlantNotes" +
            ");";

        cmd.Parameters.Add(MkParam(cmd, "@pPlantId", PlantId));
        cmd.Parameters.Add(MkParam(cmd, "@pTaxonId", TaxonId));
        cmd.Parameters.Add(MkParam(cmd, "@pPlantTag", (object?)PlantTag ?? DBNull.Value));
        cmd.Parameters.Add(MkParam(cmd, "@pPlantName", (object?)PlantName ?? DBNull.Value));
        cmd.Parameters.Add(MkParam(cmd, "@pAcquisitionDate", AcquisitionDate));
        cmd.Parameters.Add(MkParam(cmd, "@pAcquisitionSource", (object?)AcquisitionSource ?? DBNull.Value));
        cmd.Parameters.Add(MkParam(cmd, "@pEndDate", (object?)EndDate ?? DBNull.Value));
        cmd.Parameters.Add(MkParam(cmd, "@pEndNotes", (object?)EndNotes ?? DBNull.Value));
        cmd.Parameters.Add(MkParam(cmd, "@pPlantNotes", (object?)PlantNotes ?? DBNull.Value));

        await cmd.ExecuteNonQueryAsync();
    }

    private static DbParameter MkParam(DbCommand cmd, string name, object value)
    {
        var p = cmd.CreateParameter();
        p.ParameterName = name;
        p.Value = value;
        return p;
    }
}