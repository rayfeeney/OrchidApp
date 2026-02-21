using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Data.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;

namespace OrchidApp.Web.Pages.Plants.Edit;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty(SupportsGet = true)]
    public int PlantId { get; set; }

    [BindProperty, Required]
    public int TaxonId { get; set; }

    [BindProperty, StringLength(50)]
    public string? PlantTag { get; set; }

    [BindProperty, StringLength(100)]
    public string? PlantName { get; set; }

    // Required: you said acquisitionDate NULL should never be allowed in edit
    [BindProperty, Required]
    public DateTime AcquisitionDate { get; set; }

    [BindProperty, StringLength(150)]
    public string? AcquisitionSource { get; set; }

    [BindProperty]
    public DateTime? EndDate { get; set; }

    [BindProperty]
    public string? EndNotes { get; set; }

    [BindProperty]
    public string? PlantNotes { get; set; }

    public SelectList TaxonOptions { get; private set; } = default!;

    public async Task<IActionResult> OnGetAsync()
    {
        // Load plant row (assumes you have a Plant entity mapped to the plant table)
        var plant = await _db.Plants
            .AsNoTracking()
            .SingleOrDefaultAsync(p => p.PlantId == PlantId);

        if (plant is null)
            return NotFound();

        TaxonId = plant.TaxonId;
        PlantTag = plant.PlantTag;
        PlantName = plant.PlantName;
        AcquisitionDate = plant.AcquisitionDate ?? DateTime.Now; // should be non-null in DB, but safe
        AcquisitionSource = plant.AcquisitionSource;
        EndDate = plant.EndDate;
        EndNotes = plant.EndNotes;
        PlantNotes = plant.PlantNotes;

        await LoadTaxonOptionsAsync();
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        await LoadTaxonOptionsAsync();

        if (!ModelState.IsValid)
            return Page();

        try
        {
            await CallSpUpdatePlantDetailsAsync();
        }
        catch (DbException ex)
        {
            // This will surface your SIGNAL MESSAGE_TEXT nicely.
            ModelState.AddModelError(string.Empty, ex.GetBaseException().Message);
            return Page();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }

    private async Task LoadTaxonOptionsAsync()
    {
        // Prefer your projection/view if you have one. Otherwise swap this for a taxon/genus query.
        var taxa = await _db.TaxonIdentities
            .AsNoTracking()
            .Where(t => t.IsActive)
            .OrderBy(t => t.DisplayName)
            .Select(t => new { t.TaxonId, t.DisplayName })
            .ToListAsync();

        TaxonOptions = new SelectList(taxa, "TaxonId", "DisplayName", TaxonId);
    }

    private async Task CallSpUpdatePlantDetailsAsync()
    {
        var conn = _db.Database.GetDbConnection();

        await using var _ = conn; // keep analyser calm; EF owns connection lifetime
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