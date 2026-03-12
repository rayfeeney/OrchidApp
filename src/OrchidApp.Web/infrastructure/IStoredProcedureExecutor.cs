using System.Data.Common;

namespace OrchidApp.Web.Infrastructure;

public interface IStoredProcedureExecutor
{
    Task<T> QuerySingleAsync<T>(
        string procedureCallSql,
        params object?[] parameters
    ) where T : new();
}