using System.Data;

namespace OrchidApp.Web.Infrastructure;

public sealed class StoredProcedureParameter
{
    public string Name { get; }
    public object? Value { get; }
    public DbType? DbType { get; }
    public ParameterDirection Direction { get; }

    public StoredProcedureParameter(
        string name,
        object? value,
        ParameterDirection direction = ParameterDirection.Input,
        DbType? dbType = null)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Parameter name is required.", nameof(name));

        Name = name.StartsWith("@", StringComparison.Ordinal) ? name : "@" + name;
        Value = value;
        Direction = direction;
        DbType = dbType;
    }
}