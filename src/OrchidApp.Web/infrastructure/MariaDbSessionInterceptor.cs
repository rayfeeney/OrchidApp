using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace OrchidApp.Web.Infrastructure;

internal sealed class MariaDbSessionInterceptor(bool useLegacyCurrentReads) : DbConnectionInterceptor
{
    private const string SetCollation = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;";
    private const string PreserveCurrentReads = "SET SESSION innodb_snapshot_isolation=OFF;";

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        using var command = CreateSessionCommand(connection);
        command.ExecuteNonQuery();
    }

    public override async Task ConnectionOpenedAsync(
        DbConnection connection,
        ConnectionEndEventData eventData,
        CancellationToken cancellationToken = default)
    {
        using var command = CreateSessionCommand(connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private DbCommand CreateSessionCommand(DbConnection connection)
    {
        var command = connection.CreateCommand();
        // Apply again on each logical open because the provider resets pooled sessions.
        command.CommandText = useLegacyCurrentReads ? SetCollation + PreserveCurrentReads : SetCollation;
        return command;
    }
}
