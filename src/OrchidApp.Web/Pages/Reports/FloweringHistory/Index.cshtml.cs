using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Reports.FloweringHistory
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

        public List<Genus> Genera { get; set; } = new();

        public List<PlantSinceLastFlowered> Plants { get; set; } = new();

        public async Task OnGetAsync()
        {
            Genera = await _context.Genera
                .Where(g => g.IsActive)
                .OrderBy(g => g.Name)
                .ToListAsync();

            var data = await _context.PlantSinceLastFlowered
                .ToListAsync();

            if (GenusId.HasValue)
            {
                data = data
                    .Where(x => x.GenusId == GenusId.Value)
                    .ToList();
            }

            Plants = data
                .OrderBy(x => x.LastFlowerEndDate == null)
                .ThenByDescending(x => x.MonthsSinceFlower)
                .ThenBy(x => x.AcquisitionDate)
                .ToList();
        }
    }
}