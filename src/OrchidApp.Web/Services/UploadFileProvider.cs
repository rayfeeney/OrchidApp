using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Primitives;

namespace OrchidApp.Web.Services;

// An initially missing directory must not permanently disable upload serving
// after an operator repairs storage and readiness becomes healthy.
public sealed class UploadFileProvider(string root) : IFileProvider
{
    public IFileInfo GetFileInfo(string subpath)
    {
        var parts = subpath.Replace('\\', '/').Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Any(part => part is "." or "..") ||
            (parts.Length != 0 && (parts[0].Equals(".photo-recovery", StringComparison.OrdinalIgnoreCase) ||
                                  parts[0].StartsWith(".readiness-", StringComparison.OrdinalIgnoreCase))))
            return new NotFoundFileInfo(subpath);
        if (!Directory.Exists(root)) return new NotFoundFileInfo(subpath);
        using var provider = new PhysicalFileProvider(root);
        return provider.GetFileInfo(subpath);
    }
    public IDirectoryContents GetDirectoryContents(string subpath) => NotFoundDirectoryContents.Singleton;
    public IChangeToken Watch(string filter) => NullChangeToken.Singleton;
}
