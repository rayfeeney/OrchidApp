using System.Data;
using System.Reflection;
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
        string procedureName,
        params StoredProcedureParameter[] parameters
    ) where T : new()
    {
        var results = await QueryListAsync<T>(procedureName, parameters);

        if (results.Count == 0)
            throw new InvalidOperationException(
                $"Stored procedure returned no rows: {procedureName}"
            );

        if (results.Count > 1)
            throw new InvalidOperationException(
                $"Stored procedure returned more than one row: {procedureName}"
            );

        return results[0];
    }

    public async Task<List<T>> QueryListAsync<T>(
        string procedureName,
        params StoredProcedureParameter[] parameters
    ) where T : new()
    {
        var conn = _db.Database.GetDbConnection();

        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = BuildCallSql(procedureName, parameters);
        cmd.CommandType = CommandType.Text;

        foreach (var p in parameters)
        {
            var dbp = cmd.CreateParameter();
            dbp.ParameterName = p.Name;
            dbp.Direction = p.Direction;

            if (p.DbType.HasValue)
                dbp.DbType = p.DbType.Value;

            object? rawValue = p.Value;

            if (rawValue is string s)
            {
                if (string.IsNullOrWhiteSpace(s) ||
                    s.Equals("null", StringComparison.OrdinalIgnoreCase))
                {
                    rawValue = null;
                }
            }

dbp.Value = rawValue ?? DBNull.Value;

            cmd.Parameters.Add(dbp);
        }

        await using var reader = await cmd.ExecuteReaderAsync();

        var results = new List<T>();

        while (await reader.ReadAsync())
        {
            results.Add(Map<T>(reader));
        }

        return results;
    }

    private static string BuildCallSql(string name, StoredProcedureParameter[] parameters)
    {
        if (parameters.Length == 0)
            return $"CALL {name}()";

        var placeholders = string.Join(",", parameters.Select(p => p.Name));
        return $"CALL {name}({placeholders})";
    }

    private static T Map<T>(IDataRecord reader) where T : new()
    {
        var obj = new T();

        var props = typeof(T)
            .GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

        for (int i = 0; i < reader.FieldCount; i++)
        {
            var name = reader.GetName(i);

            if (!props.TryGetValue(name, out var prop))
                continue;

            if (reader.IsDBNull(i))
                continue;

            var value = reader.GetValue(i);
            var targetType = Nullable.GetUnderlyingType(prop.PropertyType) ?? prop.PropertyType;
            value = Convert.ChangeType(value, targetType);
            prop.SetValue(obj, value);
        }

        return obj;
    }
}