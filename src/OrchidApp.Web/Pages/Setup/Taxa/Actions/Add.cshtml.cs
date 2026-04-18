using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using System.ComponentModel.DataAnnotations;
using System.Data.Common;
using OrchidApp.Web.Infrastructure;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

namespace OrchidApp.Web.Pages.Setup.Taxa.Actions;

public class AddModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;
    private readonly IStoredProcedureExecutor _sp;
    private readonly PhotoPipeline _photoPipeline;
    private readonly StoragePathService _storagePathService;

    public AddModel(
        OrchidDbContext db,
        IStoredProcedureExecutor sp,
        PhotoPipeline photoPipeline,
        StoragePathService storagePathService)
    {
        _db = db;
        _sp = sp;
        _photoPipeline = photoPipeline;
        _storagePathService = storagePathService;
    }

    public List<GenusLookup> Genera { get; private set; } = [];

    [BindProperty, Required]
    [Display(Name = "Genus")]
    public int? GenusId { get; set; }


    [BindProperty]
    [Display(Name = "Species name")]
    public string? SpeciesName { get; set; }

    [BindProperty]
    [Display(Name = "Hybrid name")]
    public string? HybridName { get; set; }

    [BindProperty]
    [Display(Name = "Growth notes")]
    public string? GrowthNotes { get; set; }

    [BindProperty]
    [Display(Name = "Notes")]
    public string? TaxonNotes { get; set; }

    [BindProperty]
    public IFormFile? Photo { get; set; }

    public async Task OnGetAsync()
    {
        Genera = await _db.Genera
            .Where(g => g.IsActive)
            .OrderBy(g => g.Name)
            .Select(g => new GenusLookup
            {
                GenusId = g.GenusId,
                GenusName = g.Name
            })
            .ToListAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        SpeciesName = string.IsNullOrWhiteSpace(SpeciesName) ? null : SpeciesName.Trim();
        HybridName = string.IsNullOrWhiteSpace(HybridName) ? null : HybridName.Trim();
        GrowthNotes = string.IsNullOrWhiteSpace(GrowthNotes) ? null : GrowthNotes.Trim();
        TaxonNotes = string.IsNullOrWhiteSpace(TaxonNotes) ? null : TaxonNotes.Trim();

        if (SpeciesName is null && HybridName is null)
        {
            ModelState.AddModelError(string.Empty,
                "You must enter either a species or a hybrid name.");
        }

        if (SpeciesName is not null && HybridName is not null)
        {
            ModelState.AddModelError(string.Empty,
                "Enter either a species OR a hybrid, not both.");
        }

        if (!ModelState.IsValid)
        {
            await OnGetAsync();
            return Page();
        }

        if (string.IsNullOrWhiteSpace(SpeciesName) && string.IsNullOrWhiteSpace(HybridName))
        {
            ModelState.AddModelError("", "Enter either a species name or a hybrid name.");
        }

        if (!string.IsNullOrWhiteSpace(SpeciesName) && !string.IsNullOrWhiteSpace(HybridName))
        {
            ModelState.AddModelError("", "Enter only one: species OR hybrid.");
        }

        if (!ModelState.IsValid)
        {
            await OnGetAsync();
            return Page();
        }

        // Guard: genus must still be active
        var genusIsActive = await _db.Genera
            .Where(g => g.GenusId == GenusId)
            .Select(g => g.IsActive)
            .SingleOrDefaultAsync();

        if (!genusIsActive)
        {
            ModelState.AddModelError(string.Empty,
                "Cannot add species / hybrid because the genus is inactive.");

            await OnGetAsync();
            return Page();
        }

        try
        {
            var result = await _sp.QuerySingleAsync<AddTaxonResult>(
                "spAddTaxon",
                new StoredProcedureParameter("pGenusId", GenusId!.Value),
                new StoredProcedureParameter("pSpeciesName", SpeciesName),
                new StoredProcedureParameter("pHybridName", HybridName),
                new StoredProcedureParameter("pGrowthNotes", GrowthNotes),
                new StoredProcedureParameter("pTaxonNotes", TaxonNotes)
            );

            // NEW: process photo if provided
            if (Photo != null && Photo.Length > 0)
            {
                var uploadsRoot = _storagePathService.GetUploadRoot();

                PhotoSaveResult resultPhoto;

                try
                {
                    resultPhoto = await _photoPipeline.ProcessAndSaveAsync(
                        Photo.OpenReadStream(),
                        new PhotoStorageTarget
                        {
                            EntityType = "taxa",
                            EntityId = result.TaxonId.ToString()
                        },
                        uploadsRoot,
                        HttpContext.RequestAborted);
                }
                catch (InvalidOperationException)
                {
                    ModelState.AddModelError(string.Empty,
                        "The image could not be processed. Please try another file.");

                    await OnGetAsync();
                    return Page();
                }

                var fileName = resultPhoto.FileName;
                var thumbFileName = resultPhoto.ThumbnailFileName;

                var taxonPhoto = new TaxonPhoto
                {
                    TaxonId = result.TaxonId,
                    FileName = fileName,
                    ThumbnailFileName = thumbFileName, 
                    MimeType = resultPhoto.MimeType,
                    IsPrimary = true,
                    IsActive = true,
                    CreatedDateTime = DateTime.Now,
                    UpdatedDateTime = DateTime.Now
                };

                _db.TaxonPhotos.Add(taxonPhoto);
                await _db.SaveChangesAsync();
            }

            return RedirectToPage(
                "/Setup/Taxa/Details",
                new { id = result.TaxonId }
            );
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var message))
            {
                ModelState.AddModelError(string.Empty, message);
                await OnGetAsync();
                return Page();
            }

            throw;
        }

    }

    public class GenusLookup
    {
        public int GenusId { get; set; }
        public string GenusName { get; set; } = "";
    }
}
