using Microsoft.EntityFrameworkCore;
using MySqlConnector;

namespace OrchidApp.Web.Infrastructure;

public static class DatabaseErrorTranslator
{
    public static bool TryTranslate(Exception ex, out string message)
    {
        message = string.Empty;

        var baseEx = ex.GetBaseException();

        if (baseEx is MySqlException mysqlEx)
        {
            // SQL SIGNAL
            if (mysqlEx.SqlState == "45000")
            {
                message = mysqlEx.Message;
                return true;
            }
        }

        return false;
    }
}