using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

namespace OrchidApp.Web.Pages.Setup.Taxa.Actions;

public class EditModel : PageModel
{
    private readonly OrchidDbContext _db;
    private readonly PhotoPipeline _photoPipeline;
    private readonly StoragePathService _storagePathService;

    public EditModel(OrchidDbContext db, PhotoPipeline photoPipeline, StoragePathService storagePathService)
    {
        _db = db;
        _photoPipeline = photoPipeline;
        _storagePathService = storagePathService;
    }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    [BindProperty]
    public TaxonEditDto Taxon { get; set; } = new();
    [BindProperty]
    public IFormFile? Photo { get; set; }

    public string GenusName { get; private set; } = string.Empty;

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var result = await _db.Taxa
            .AsNoTracking()
            .Where(t => t.TaxonId == id)
            .Join(
                _db.Genera,
                t => t.GenusId,
                g => g.GenusId,
                (t, g) => new
                {
                    Taxon = new TaxonEditDto
                    {
                        TaxonId = t.TaxonId,
                        GenusId = t.GenusId,
                        IsSystemManaged = t.IsSystemManaged,
                        SpeciesName = t.SpeciesName,
                        HybridName = t.HybridName,
                        GrowthCode = t.GrowthCode,
                        GrowthNotes = t.GrowthNotes,
                        TaxonNotes = t.TaxonNotes
                    },
                    GenusName = g.Name,
                    GenusIsActive = g.IsActive,
                    TaxonIsActive = t.IsActive
                }
            )
            .SingleOrDefaultAsync();

        if (result == null)
            return NotFound();

        Taxon = result.Taxon;
        GenusName = result.GenusName;
        GenusIsActive = result.GenusIsActive;
        TaxonIsActive = result.TaxonIsActive;
    
        return Page();
        
    }

    public async Task<IActionResult> OnPostAsync(int id)
    {
        if (!ModelState.IsValid)
        {
            await ReloadGenusNameAsync(id);
            return Page();
        }

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateTaxonDetails({0},{1},{2},{3},{4},{5})",
                id,
                (object?)Taxon.SpeciesName!,
                (object?)Taxon.HybridName!,
                (object?)Taxon.GrowthCode!,
                (object?)Taxon.GrowthNotes!,
                (object?)Taxon.TaxonNotes!
            );
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            await ReloadGenusNameAsync(id);
            return Page();
        }

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
                EntityId = id.ToString()
            },
            uploadsRoot,
            HttpContext.RequestAborted);
    }
    catch (InvalidOperationException)
    {
        ModelState.AddModelError(string.Empty,
            "The image could not be processed. Please try another file.");

        await OnGetAsync(id);
        return Page();
    }

    var fileName = resultPhoto.FileName;
    var thumbFileName = resultPhoto.ThumbnailFileName;

    // deactivate existing photos
    var existingPhotos = await _db.TaxonPhotos
        .Where(p => p.TaxonId == id && p.IsActive)
        .ToListAsync();

    foreach (var photo in existingPhotos)
    {
        photo.IsActive = false;
        photo.IsPrimary = false;
    }

    // insert new photo
    var newPhoto = new TaxonPhoto
    {
        TaxonId = id,
        FileName = fileName,
        ThumbnailFileName = thumbFileName,
        MimeType = resultPhoto.MimeType,
        IsPrimary = true,
        IsActive = true,
        CreatedDateTime = DateTime.Now,
        UpdatedDateTime = DateTime.Now
    };

    _db.TaxonPhotos.Add(newPhoto);

    await _db.SaveChangesAsync();
}

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Taxa/Details", new { id })!);
    }

    private async Task ReloadGenusNameAsync(int taxonId)
    {
        GenusName = await _db.Taxa
            .Where(t => t.TaxonId == taxonId)
            .Join(
                _db.Genera,
                t => t.GenusId,
                g => g.GenusId,
                (t, g) => g.Name
            )
            .SingleOrDefaultAsync()
            ?? "(unknown genus)";
    }
}