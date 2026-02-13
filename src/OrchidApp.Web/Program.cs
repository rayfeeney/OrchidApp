using OrchidApp.Web.Data;
using OrchidApp.Web.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages();

builder.Services.AddDbContext<OrchidDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("OrchidDb");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "Connection string 'OrchidDb' is missing.");
        }
    options.UseMySql(connectionString,new MySqlServerVersion(new Version(10, 6, 0))
);

});

builder.Services.AddScoped<ObservationTypeResolver>();


var app = builder.Build();



// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

app.Run();
