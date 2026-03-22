using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Services;
using Microsoft.AspNetCore.Http;
using OrchidApp.Web.Infrastructure;
using Microsoft.Extensions.Logging;

namespace OrchidApp.Web.Pages.Plants.Events;

public class AddModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;
    private readonly ObservationTypeResolver _resolver;
    private readonly PhotoPipeline _photoPipeline;
    private readonly IStoredProcedureExecutor _sp;
    private readonly ILogger<AddModel> _logger;

    public AddModel(
        OrchidDbContext db,
        ObservationTypeResolver resolver,
        PhotoPipeline photoPipeline,
        IStoredProcedureExecutor sp,
        ILogger<AddModel> logger)
    {
        _db = db;
        _resolver = resolver;
        _photoPipeline = photoPipeline;
        _sp = sp;
        _logger = logger;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    [FromRoute]
    public string EventType { get; set; } = "Observation";

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime EventDate { get; set; } = DateTime.Today;

    [BindProperty]
    public string? EventDetails { get; set; }

    [BindProperty]
    public List<IFormFile>? UploadedFiles { get; set; }

    public bool ShowPhotoSection { get; set; }

    [BindProperty]
    public int LocationId { get; set; }

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime StartDate { get; set; } = DateTime.Today;

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime? EndDate { get; set; }

    [BindProperty] public int? SpikeCount { get; set; }
    [BindProperty] public int? FlowerCount { get; set; }
    [BindProperty] public string? PlantLocationNotes { get; set; }

    [BindProperty] public int? OldGrowthMediumId { get; set; }
    [BindProperty] public int? NewGrowthMediumId { get; set; }
    [BindProperty] public string? OldMediumNotes { get; set; }
    [BindProperty] public string? NewMediumNotes { get; set; }
    [BindProperty] public string? PotSize { get; set; }
    [BindProperty] public string? RepotReasonNotes { get; set; }
    [BindProperty] public string? RepottingNotes { get; set; }

    public List<Location> Locations { get; private set; } = new();
    public List<GrowthMedium> GrowthMedia { get; private set; } = new();

    private bool LoadPlantContext()
    {
        var plant = _db.PlantActiveSummaries
            .FirstOrDefault(p => p.PlantId == PlantId);

        if (plant == null)
            return false;

        PlantDisplayName = plant.DisplayName;
        PlantTag = plant.PlantTag;

        var taxon = _db.TaxonIdentities
            .Where(t => t.TaxonId == plant.TaxonId)
            .Select(t => new { t.GenusIsActive, t.TaxonIsActive })
            .Single();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        return true;
    }

    private void LoadLookups()
    {
        Locations = _db.Location.Where(l => l.IsActive)
            .OrderBy(l => l.LocationName).ToList();

        GrowthMedia = _db.GrowthMedia.Where(g => g.IsActive)
            .OrderBy(g => g.Name).ToList();
    }

    public IActionResult OnGet()
    {
        if (EventType is not ("Observation" or "LocationChange" or "Flowering" or "Repotting"))
            return NotFound();

        if (!LoadPlantContext())
            return NotFound();

        LoadLookups();
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(string? quickAction)
    {
        if (!string.IsNullOrWhiteSpace(quickAction) && EventType == "Observation")
        {
            EventDate = DateTime.Today;
            ModelState.Remove(nameof(EventDate));

            switch (quickAction)
            {
                case "photo":
                    EventDetails = "Photo added";
                    ShowPhotoSection = true;
                    break;
                case "feedGrowth":
                    EventDetails = "Fed with growth food";
                    break;
                case "feedBloom":
                    EventDetails = "Fed with bloom food";
                    break;
            }

            if (!LoadPlantContext()) return NotFound();
            LoadLookups();
            return Page();
        }

        if (!ModelState.IsValid)
        {
            if (!LoadPlantContext()) return NotFound();
            LoadLookups();
            return Page();
        }

        switch (EventType)
        {
            case "Observation":

                var hasPhotos = UploadedFiles != null && UploadedFiles.Any();
                if (hasPhotos && string.IsNullOrWhiteSpace(EventDetails))
                    EventDetails = "Photo added";

                var typeCode = hasPhotos ? "OBS_PHOTO" : "OBS_NOTE";
                var observationTypeId = await _resolver.GetIdAsync(typeCode);

                var observation = new PlantEvent
                {
                    PlantId = PlantId,
                    EventDateTime = EventDate,
                    ObservationTypeId = observationTypeId,
                    EventDetails = EventDetails,
                    IsActive = true
                };

                _db.PlantEvent.Add(observation);
                await _db.SaveChangesAsync();

                if (hasPhotos)
                {
                    var uploadsRoot = "/opt/orchidapp/uploads";

                    var heroExists = _db.PlantPhotos
                        .Any(p => p.PlantId == PlantId && p.IsHero && p.IsActive);

                    foreach (var file in UploadedFiles!)
                    {
                        if (file == null || file.Length <= 0)
                            continue;

                        PhotoSaveResult result;

                        try
                        {
                            result = await _photoPipeline.ProcessAndSaveAsync(
                                file.OpenReadStream(),
                                PlantId,
                                uploadsRoot,
                                HttpContext.RequestAborted);
                        }
                        catch (InvalidOperationException ex)
                        {
                            _logger.LogWarning(ex,
                                "Photo ingestion failed for plant {PlantId}", PlantId);

                            ModelState.AddModelError(string.Empty,
                                "The photo could not be processed. Please try another image.");

                            if (!LoadPlantContext())
                                return NotFound();

                            LoadLookups();
                            return Page();
                        }

                        var photo = new PlantPhoto
                        {
                            PlantEventId = observation.PlantEventId,
                            PlantId = PlantId,
                            FileName = file.FileName,
                            FilePath = result.RelativePath,
                            MimeType = result.MimeType,
                            IsHero = !heroExists,
                            IsActive = true,
                            CreatedDateTime = DateTime.Now
                        };

                        _db.PlantPhotos.Add(photo);

                        if (!heroExists)
                            heroExists = true;
                    }

                    await _db.SaveChangesAsync();
                }

                break;

            case "LocationChange":
                try
                {
                    await _sp.QueryListAsync<object>(
                        "spMovePlantToLocation",
                        new StoredProcedureParameter("pPlantId", PlantId),
                        new StoredProcedureParameter("pLocationId", LocationId),
                        new StoredProcedureParameter("pStartDate", EventDate.Date),
                        new StoredProcedureParameter("pMoveReasonNotes", EventDetails),
                        new StoredProcedureParameter("pPlantLocationNotes", PlantLocationNotes)
                    );
                }
                catch (Exception ex) when (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
                {
                    ModelState.AddModelError(string.Empty, msg);

                    if (!LoadPlantContext())
                        return NotFound();

                    LoadLookups();
                    return Page();
                }
                break;

            case "Flowering":

                if (EndDate.HasValue && EndDate < StartDate)
                {
                    ModelState.AddModelError("", "End date cannot be before start date.");
                    if (!LoadPlantContext()) return NotFound();
                    LoadLookups();
                    return Page();
                }

                _db.Flowering.Add(new Flowering
                {
                    PlantId = PlantId,
                    StartDate = StartDate.Date,
                    EndDate = EndDate?.Date,
                    SpikeCount = SpikeCount,
                    FlowerCount = FlowerCount,
                    FloweringNotes = EventDetails,
                    IsActive = true
                });

                await _db.SaveChangesAsync();
                break;

            case "Repotting":

                _db.Repotting.Add(new Repotting
                {
                    PlantId = PlantId,
                    RepotDate = EventDate.Date,
                    OldGrowthMediumId = OldGrowthMediumId,
                    NewGrowthMediumId = NewGrowthMediumId,
                    OldMediumNotes = OldMediumNotes,
                    NewMediumNotes = NewMediumNotes,
                    PotSize = PotSize,
                    RepotReasonNotes = RepotReasonNotes,
                    RepottingNotes = RepottingNotes,
                    IsActive = true
                });

                await _db.SaveChangesAsync();
                break;
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}