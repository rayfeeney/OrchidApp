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
        await using var conn = _db.Database.GetDbConnection();

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

            if (rawValue is string s && string.IsNullOrWhiteSpace(s))
                rawValue = null;

            dbp.Value = rawValue ?? DBNull.Value;

            cmd.Parameters.Add(dbp);
        }

        await using var reader = await cmd.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
            throw new InvalidOperationException(
                $"Stored procedure returned no rows: {procedureName}"
            );

        return Map<T>(reader);
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

            var targetType = Nullable.GetUnderlyingType(prop.PropertyType)
                             ?? prop.PropertyType;

            value = Convert.ChangeType(value, targetType);

            prop.SetValue(obj, value);
        }

        return obj;
    }
}