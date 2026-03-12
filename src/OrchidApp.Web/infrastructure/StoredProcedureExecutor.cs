using System.Data;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;

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
            throw new InvalidOperationException("Stored procedure returned no rows.");

        var result = new T();

        for (int i = 0; i < reader.FieldCount; i++)
        {
            var prop = typeof(T).GetProperty(reader.GetName(i));
            if (prop != null && !reader.IsDBNull(i))
                prop.SetValue(result, reader.GetValue(i));
        }

        return result;
    }
}