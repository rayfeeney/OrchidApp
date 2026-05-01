using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Reports.Flowering
{
    public class IndexModel : PageModel
    {
        private readonly OrchidDbContext _context;

        public IndexModel(OrchidDbContext context)
        {
            _context = context;
        }

        public List<PlantCurrentlyFlowering> Plants { get; set; } = new();

        public async Task OnGetAsync()
        {
            var data = await _context.PlantCurrentlyFlowering.ToListAsync();

            Plants = data
                .OrderBy(x => x.LocationName)
                .ThenBy(x => x.GenusName)
                .ThenBy(x => x.DisplayName)
                .ToList();
        }
    }
}