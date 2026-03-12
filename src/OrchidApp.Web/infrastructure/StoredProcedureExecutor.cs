using System.Data;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using System.Reflection;

namespace OrchidApp.Web.Infrastructure;

public class StoredProcedureExecutor : IStoredProcedureExecutor
{
    private readonly OrchidDbContext _db;

    public StoredProcedureExecutor(OrchidDbContext db)
    {
        _db = db;
    }

    public async Task<T> QuerySingleAsync<T>(
        string procedureCallSql,
        params object?[] parameters
    ) where T : new()
    {
        await using var conn = _db.Database.GetDbConnection();

        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = procedureCallSql;
        cmd.CommandType = CommandType.Text;

        for (int i = 0; i < parameters.Length; i++)
        {
            var p = cmd.CreateParameter();
            p.ParameterName = $"@p{i}";
            p.Value = parameters[i] ?? DBNull.Value;
            cmd.Parameters.Add(p);
        }

        await using var reader = await cmd.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
            throw new InvalidOperationException(
                $"Stored procedure returned no rows: {procedureCallSql}"
            );

        var result = new T();

        var props = typeof(T)
            .GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

        for (int i = 0; i < reader.FieldCount; i++)
        {
            var column = reader.GetName(i);

            if (props.TryGetValue(column, out var prop) && !reader.IsDBNull(i))
            {
                var value = reader.GetValue(i);
                prop.SetValue(result, value);
            }
        }

        return result;
    }
}