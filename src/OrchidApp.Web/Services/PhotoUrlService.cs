namespace OrchidApp.Web.Services;

public class PhotoUrlService
{
    public string GetPlantPhoto(int plantId, string fileName)
        => $"/uploads/plants/{plantId}/{fileName}";

    public string GetPlantThumbnail(int plantId, string? thumbnailFileName, string fileName)
    {
        if (!string.IsNullOrWhiteSpace(thumbnailFileName))
        {
            return $"/uploads/plants/{plantId}/{thumbnailFileName}";
        }

        return GetPlantPhoto(plantId, fileName); 
    }

    public string GetTaxonPhoto(int taxonId, string fileName)
        => $"/uploads/taxa/{taxonId}/{fileName}";

    public string GetTaxonThumbnail(int taxonId, string fileName)
        => $"/uploads/taxa/{taxonId}/{fileName}";
}