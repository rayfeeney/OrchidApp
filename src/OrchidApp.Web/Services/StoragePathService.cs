using Microsoft.Extensions.Options;
using OrchidApp.Web.Configuration;

namespace OrchidApp.Web.Services;

public class StoragePathService
{
    private readonly StorageSettings _storage;

    public StoragePathService(IOptions<StorageSettings> options)
    {
        _storage = options.Value;
    }

    public string GetUploadRoot()
    {
        return _storage.UploadRoot;
    }
}