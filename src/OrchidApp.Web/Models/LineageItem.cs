using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class LineageItem
{
    public int PlantId { get; set; }

    public string PlantTag { get; set; } = "";

    public DateTime? AcquisitionDate { get; set; }

    public DateTime? EndDate { get; set; }

    public int Level { get; set; }

    public List<ChildPlantLink> Children { get; set; } = [];
}