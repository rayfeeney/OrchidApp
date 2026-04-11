using System;

namespace OrchidApp.Web.Models;

public class PlantSplitChildren
{
    public int ParentPlantId { get; set; }
    public int ChildPlantId { get; set; }
    public string? PlantTag { get; set; }
    public DateOnly? AcquisitionDate { get; set; }
}