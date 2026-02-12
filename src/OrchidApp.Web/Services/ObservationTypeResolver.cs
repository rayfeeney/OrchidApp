using OrchidApp.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Services
{
    public class ObservationTypeResolver
    {
        private readonly OrchidDbContext _context;

        public ObservationTypeResolver(OrchidDbContext context)
        {
            _context = context;
        }

        public async Task<int> GetIdAsync(string typeCode)
        {
            return await _context.ObservationTypes
                .Where(x => x.TypeCode == typeCode && x.IsActive)
                .Select(x => x.Id)
                .SingleAsync();
        }
    }
}
