using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Services;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Maintenance;

public class BackfillPlantPhotoThumbnailsModel : PageModel
{
    private readonly OrchidDbContext _db;
    private readonly StoragePathService _storagePathService;
    private readonly ILogger<BackfillPlantPhotoThumbnailsModel> _logger;

    public BackfillPlantPhotoThumbnailsModel(
        OrchidDbContext db,
        StoragePathService storagePathService,
        ILogger<BackfillPlantPhotoThumbnailsModel> logger)
    {
        _db = db;
        _storagePathService = storagePathService;
        _logger = logger;
    }

    [BindProperty]
    [Display(Name = "Maintenance key")]
    public string? Key { get; set; }

    public string? Message { get; private set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync()
    {
        // 🔐 Safety gate
        if (Key != "run-once-2026")
        {
            ModelState.AddModelError(nameof(Key), "Invalid maintenance key.");
            return Page();
        }

var uploadsRoot = _storagePathService.GetUploadRoot();

var missing = await _db.PlantPhotos
    .Where(p => p.ThumbnailFileName == null)
    .OrderBy(p => p.PlantPhotoId)
    .ToListAsync();

int checkedCount = 0;
int existsCount = 0;

foreach (var photo in missing.Take(10)) // limit to 10 for safety
{
    var folder = Path.Combine(
        uploadsRoot,
        "plants",
        photo.PlantId.ToString());

    var sourcePath = Path.Combine(folder, photo.FileName);

    var exists = System.IO.File.Exists(sourcePath);

    if (exists) existsCount++;

    _logger.LogInformation(
        "Check PlantPhotoId={PlantPhotoId}, Exists={Exists}, Path={Path}",
        photo.PlantPhotoId,
        exists,
        sourcePath);

    checkedCount++;
}

Message = $"Checked {checkedCount} records. Files found: {existsCount}. See logs.";

return Page();
    }
}