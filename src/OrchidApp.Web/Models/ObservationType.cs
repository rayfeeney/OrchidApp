namespace OrchidApp.Web.Models
{
    public class ObservationType
    {
        public int Id { get; set; }

        public string TypeCode { get; set; } = default!;
        public string DisplayName { get; set; } = default!;

        public bool IsSystem { get; set; }
        public bool IsActive { get; set; }

        public DateTime CreatedDateTime { get; set; }
        public DateTime? UpdatedDateTime { get; set; }
    }
}
