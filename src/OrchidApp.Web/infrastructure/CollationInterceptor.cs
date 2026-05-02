using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

public class CollationInterceptor : DbConnectionInterceptor
{
    public override async Task ConnectionOpenedAsync(
    DbConnection connection,
    ConnectionEndEventData eventData,
    CancellationToken cancellationToken = default)
{
    using var cmd = connection.CreateCommand();
    cmd.CommandText = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;";
    await cmd.ExecuteNonQueryAsync(cancellationToken);
}
}