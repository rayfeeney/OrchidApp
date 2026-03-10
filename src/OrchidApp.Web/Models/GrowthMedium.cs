using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class GrowthMedium
{
    public int GrowthMediumId { get; set; }

    [Display(Name = "Name")]
    public string Name { get; set; } = string.Empty;

    [Display(Name = "Description")]
    public string? Description { get; set; }

    public bool IsActive { get; set; }

    public DateTime CreatedDateTime { get; set; }

    public DateTime UpdatedDateTime { get; set; }
}

public class GrowthMediumIdResult
{
    public int GrowthMediumId { get; set; }
}