namespace OrchidApp.Web.Infrastructure;

public interface IStoredProcedureExecutor
{
    Task<T> QuerySingleAsync<T>(
        string procedureName,
        params StoredProcedureParameter[] parameters
    ) where T : new();

    Task<List<T>> QueryListAsync<T>(
        string procedureName,
        params StoredProcedureParameter[] parameters
    ) where T : new();
}