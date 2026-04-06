using OrchidApp.Web.Data;
using OrchidApp.Web.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.Extensions.FileProviders;
using OrchidApp.Web.Infrastructure;
using OrchidApp.Web.Configuration;


var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages();

builder.Services.AddDbContext<OrchidDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("OrchidDb");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "Connection string 'OrchidDb' is not configured. " +
                "Ensure Production provides it via environment configuration.");
        }
    options.UseMySql(connectionString,new MySqlServerVersion(new Version(10, 6, 0))
);

});


builder.Services.AddSingleton<PhotoPipeline>();

builder.Services.Configure<MediaIngestionOptions>(
    builder.Configuration.GetSection("MediaIngestion"));

builder.Services.Configure<StorageSettings>(
    builder.Configuration.GetSection("Storage"));

builder.Services.AddScoped<StoragePathService>();
    
builder.Services.AddScoped<ObservationTypeResolver>();

builder.Services.AddScoped<IStoredProcedureExecutor, StoredProcedureExecutor>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles(); // always serve wwwroot (Dev + Prod)

var uploadsPath = builder.Configuration["Storage:UploadRoot"];

if (Directory.Exists(uploadsPath))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(uploadsPath),
        RequestPath = "/uploads"
    });
}

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

app.Run();
