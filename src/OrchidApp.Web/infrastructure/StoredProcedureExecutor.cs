using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using OrchidApp.Web.Data;

namespace OrchidApp.Web.Infrastructure;

public sealed class StoredProcedureExecutor : IStoredProcedureExecutor
{
    private readonly OrchidDbContext _db;

    public StoredProcedureExecutor(OrchidDbContext db)
    {
        _db = db;
    }

    public async Task<T> ExecuteWithOutputAsync<T>(
        string procedureName,
        IReadOnlyCollection<StoredProcedureParameter> inputParameters,
        IReadOnlyCollection<StoredProcedureParameter> outputParameters,
        Func<IReadOnlyDictionary<string, object?>, T> mapOutput,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(procedureName);

        if (mapOutput is null)
            throw new ArgumentNullException(nameof(mapOutput));

        inputParameters ??= Array.Empty<StoredProcedureParameter>();
        outputParameters ??= Array.Empty<StoredProcedureParameter>();

        ValidateParameters(inputParameters, outputParameters);

        var connection = _db.Database.GetDbConnection();
        var shouldCloseConnection = connection.State != ConnectionState.Open;

        if (shouldCloseConnection)
            await connection.OpenAsync(cancellationToken);

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandType = CommandType.Text;
            command.CommandText = BuildCallSql(procedureName, inputParameters, outputParameters);

            var currentTransaction = _db.Database.CurrentTransaction;
            if (currentTransaction is not null)
            {
                command.Transaction = currentTransaction.GetDbTransaction();
            }

            AddParameters(command, inputParameters);
            AddParameters(command, outputParameters);

            await command.ExecuteNonQueryAsync(cancellationToken);

            var outputs = ReadOutputs(command, outputParameters);

            return mapOutput(outputs);
        }
        finally
        {
            if (shouldCloseConnection)
                await connection.CloseAsync();
        }
    }

    private static void ValidateParameters(
        IReadOnlyCollection<StoredProcedureParameter> inputParameters,
        IReadOnlyCollection<StoredProcedureParameter> outputParameters)
    {
        var allNames = inputParameters
            .Concat(outputParameters)
            .Select(p => p.Name)
            .ToList();

        var duplicateNames = allNames
            .GroupBy(n => n, StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key)
            .ToList();

        if (duplicateNames.Count != 0)
        {
            throw new ArgumentException(
                $"Duplicate stored procedure parameter name(s): {string.Join(", ", duplicateNames)}");
        }

        foreach (var parameter in inputParameters)
        {
            if (parameter.Direction != ParameterDirection.Input)
            {
                throw new ArgumentException(
                    $"Input parameter '{parameter.Name}' must use ParameterDirection.Input.");
            }
        }

        foreach (var parameter in outputParameters)
        {
            if (parameter.Direction is not ParameterDirection.Output and not ParameterDirection.InputOutput)
            {
                throw new ArgumentException(
                    $"Output parameter '{parameter.Name}' must use Output or InputOutput direction.");
            }

            if (parameter.DbType is null)
            {
                throw new ArgumentException(
                    $"Output parameter '{parameter.Name}' must declare a DbType.");
            }
        }
    }

    private static string BuildCallSql(
        string procedureName,
        IReadOnlyCollection<StoredProcedureParameter> inputParameters,
        IReadOnlyCollection<StoredProcedureParameter> outputParameters)
    {
        var parameterList = inputParameters
            .Concat(outputParameters)
            .Select(p => p.Name);

        return $"CALL {procedureName}({string.Join(", ", parameterList)})";
    }

    private static void AddParameters(
        IDbCommand command,
        IReadOnlyCollection<StoredProcedureParameter> parameters)
    {
        foreach (var parameter in parameters)
        {
            var dbParameter = command.CreateParameter();
            dbParameter.ParameterName = parameter.Name;
            dbParameter.Direction = parameter.Direction;
            dbParameter.Value = parameter.Value ?? DBNull.Value;

            if (parameter.DbType.HasValue)
                dbParameter.DbType = parameter.DbType.Value;

            command.Parameters.Add(dbParameter);
        }
    }

    private static IReadOnlyDictionary<string, object?> ReadOutputs(
        IDbCommand command,
        IReadOnlyCollection<StoredProcedureParameter> outputParameters)
    {
        var results = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

        foreach (var parameter in outputParameters)
        {
            var value = ((IDataParameter)command.Parameters[parameter.Name]!).Value;
            results[parameter.Name] = value is DBNull ? null : value;
        }

        return results;
    }
}