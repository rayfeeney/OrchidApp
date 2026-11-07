using System.Globalization;
using System.Text.RegularExpressions;

namespace OrchidApp.Web.Services;

public static class PhotoDeletionPaths
{
    public static string Resolve(string root, int plantId, string name)
    {
        if (!Path.IsPathFullyQualified(root) || plantId <= 0 ||
            !Regex.IsMatch(name, @"\A[a-zA-Z0-9_-]+\.(?:jpg|jpeg|png|webp)\z", RegexOptions.IgnoreCase))
            throw new InvalidOperationException("Unsafe photo storage path.");
        var path = Path.Combine(Path.GetFullPath(root), "plants", plantId.ToString(CultureInfo.InvariantCulture), name);
        Validate(path);
        return path;
    }

    // Reject links/junctions on both platforms, including on ancestor folders.
    public static void Validate(string path)
    {
        for (string? current = path; current != null; current = Path.GetDirectoryName(current))
        {
            try
            {
                var attributes = File.GetAttributes(current);
                if ((attributes & FileAttributes.ReparsePoint) != 0 ||
                    (current == path && (attributes & FileAttributes.Directory) != 0))
                    throw new InvalidOperationException("Unsafe photo storage path.");
            }
            catch (FileNotFoundException) { }
            catch (DirectoryNotFoundException) { }
        }
    }
}
