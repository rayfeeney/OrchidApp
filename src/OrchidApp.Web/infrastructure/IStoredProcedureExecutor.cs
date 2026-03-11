using System.Data;

namespace OrchidApp.Web.Infrastructure;

public interface IStoredProcedureExecutor
{
    Task<T> ExecuteWithOutputAsync<T>(
        string procedureName,
        IReadOnlyCollection<StoredProcedureParameter> inputParameters,
        IReadOnlyCollection<StoredProcedureParameter> outputParameters,
        Func<IReadOnlyDictionary<string, object?>, T> mapOutput,
        CancellationToken cancellationToken = default);
}