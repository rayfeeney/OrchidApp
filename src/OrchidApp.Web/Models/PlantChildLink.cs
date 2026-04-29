public class PlantChildLink
{
    public int ParentPlantId { get; set; }
    public int ChildPlantId { get; set; }
    public string PlantTag { get; set; } = "";
    public DateTime? AcquisitionDate { get; set; }
    public string RelationshipType { get; set; } = "";
}