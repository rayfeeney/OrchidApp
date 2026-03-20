namespace OrchidApp.Web.Infrastructure;

public interface IStoredProcedureExecutor
{
    Task<T> QuerySingleAsync<T>(
        string procedureName,
        params StoredProcedureParameter[] parameters
    ) where T : new();
}