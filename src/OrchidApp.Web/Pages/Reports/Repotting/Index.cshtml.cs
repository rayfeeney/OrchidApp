using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Reports.Repotting
{
    public class IndexModel : PageModel
    {
        private readonly OrchidDbContext _context;

        public IndexModel(OrchidDbContext context)
        {
            _context = context;
        }

        [BindProperty(SupportsGet = true)]
        public int? GenusId { get; set; }

        public List<PlantRepotStatus> Plants { get; set; } = new();

        public List<Genus> Genera { get; set; } = new();

        public async Task OnGetAsync()
        {
            // Populate filter dropdown
            Genera = await _context.Genera
                .Where(g => g.IsActive)
                .OrderBy(g => g.Name)
                .ToListAsync();

            var data = await _context.PlantRepotStatuses
                .ToListAsync();   // force SQL execution first

            if (GenusId.HasValue)
            {
                data = data
                    .Where(x => x.GenusId == GenusId.Value)
                    .ToList();
            }

            Plants = data
                .OrderBy(x => x.MonthsSinceRepot != null)
                .ThenByDescending(x => x.MonthsSinceRepot)
                .ThenByDescending(x => x.LastRepotDate.HasValue)
                .ThenByDescending(x => x.LastRepotDate)
                .ThenByDescending(x => x.AcquisitionDate)
                .ToList();
        }
    }
}