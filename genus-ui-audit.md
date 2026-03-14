# Genus UI surface audit

Generated: 03/14/2026 14:35:48
Root: src\OrchidApp.Web

## DisplayNameUsage

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 226
Reason: Botanical displayName used — badge policy must be applied
Text: entity.Property(e => e.DisplayName)             .HasColumnName("displayName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 251
Reason: Botanical displayName used — badge policy must be applied
Text: entity.Property(e => e.DisplayName)             .HasColumnName("displayName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 270
Reason: Botanical displayName used — badge policy must be applied
Text: entity.Property(e => e.DisplayName)             .HasColumnName("displayName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 287
Reason: Botanical displayName used — badge policy must be applied
Text: entity.Property(e => e.DisplayName)             .HasColumnName("displayName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\Location.cs
Line: 34
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName => LocationName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\ObservationType.cs
Line: 8
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = default!;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\PlantActiveCurrentLocation.cs
Line: 17
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\PlantActiveSummary.cs
Line: 18
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\PlantCurrentLocation.cs
Line: 14
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\PlantPhoto.cs
Line: 24
Reason: Botanical displayName used — badge policy must be applied
Text: public string PlantDisplayName { get; private set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\TaxonIdentity.cs
Line: 18
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\obj\Debug\net8.0\.NETCoreApp,Version=v8.0.AssemblyAttributes.cs
Line: 4
Reason: Botanical displayName used — badge policy must be applied
Text: [assembly: global::System.Runtime.Versioning.TargetFrameworkAttribute(".NETCoreApp,Version=v8.0", FrameworkDisplayName = ".NET 8.0")]

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\obj\Debug\net9.0\.NETCoreApp,Version=v9.0.AssemblyAttributes.cs
Line: 4
Reason: Botanical displayName used — badge policy must be applied
Text: [assembly: global::System.Runtime.Versioning.TargetFrameworkAttribute(".NETCoreApp,Version=v9.0", FrameworkDisplayName = ".NET 9.0")]

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\obj\Release\net8.0\.NETCoreApp,Version=v8.0.AssemblyAttributes.cs
Line: 4
Reason: Botanical displayName used — badge policy must be applied
Text: [assembly: global::System.Runtime.Versioning.TargetFrameworkAttribute(".NETCoreApp,Version=v8.0", FrameworkDisplayName = ".NET 8.0")]

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Add\Create.cshtml
Line: 13
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.Taxon.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Add\Index.cshtml
Line: 31
Reason: Botanical displayName used — badge policy must be applied
Text: @taxon.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 6
Reason: Botanical displayName used — badge policy must be applied
Text: @if (!string.IsNullOrEmpty(Model.SelectedDisplayName))

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 9
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.SelectedDisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 37
Reason: Botanical displayName used — badge policy must be applied
Text: public string? SelectedDisplayName { get; private set; }

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 122
Reason: Botanical displayName used — badge policy must be applied
Text: SelectedDisplayName = selected.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 209
Reason: Botanical displayName used — badge policy must be applied
Text: .ThenBy(t => t.DisplayName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 212
Reason: Botanical displayName used — badge policy must be applied
Text: SelectedDisplayName = taxa

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 214
Reason: Botanical displayName used — badge policy must be applied
Text: .DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Add.cshtml
Line: 17
Reason: Botanical displayName used — badge policy must be applied
Text: @if (Model.PlantDisplayName != null)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Add.cshtml
Line: 20
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.PlantDisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Add.cshtml.cs
Line: 94
Reason: Botanical displayName used — badge policy must be applied
Text: public string? PlantDisplayName { get; private set; }

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Add.cshtml.cs
Line: 192
Reason: Botanical displayName used — badge policy must be applied
Text: PlantDisplayName = plant.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Edit.cshtml
Line: 17
Reason: Botanical displayName used — badge policy must be applied
Text: @if (Model.PlantDisplayName != null)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Edit.cshtml
Line: 20
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.PlantDisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Edit.cshtml.cs
Line: 124
Reason: Botanical displayName used — badge policy must be applied
Text: public string? PlantDisplayName { get; private set; }

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Edit.cshtml.cs
Line: 135
Reason: Botanical displayName used — badge policy must be applied
Text: PlantDisplayName = plant.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Events\Split.cshtml
Line: 7
Reason: Botanical displayName used — badge policy must be applied
Text: <span>@Model.Plant?.DisplayName</span>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Photos\Index.cshtml
Line: 7
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.PlantDisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Photos\Index.cshtml.cs
Line: 43
Reason: Botanical displayName used — badge policy must be applied
Text: public string PlantDisplayName { get; private set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Photos\Index.cshtml.cs
Line: 125
Reason: Botanical displayName used — badge policy must be applied
Text: DisplayName = p.DisplayName!,

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Photos\Index.cshtml.cs
Line: 134
Reason: Botanical displayName used — badge policy must be applied
Text: PlantDisplayName = plant.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Details.cshtml
Line: 5
Reason: Botanical displayName used — badge policy must be applied
Text: ViewData["Title"] = Model.PlantRequired.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Details.cshtml
Line: 9
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.PlantRequired.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Details.cshtml
Line: 26
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.PlantRequired.PlantTag)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Details.cshtml
Line: 35
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.PlantRequired.PlantName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Details.cshtml
Line: 44
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.PlantRequired.LocationName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml
Line: 39
Reason: Botanical displayName used — badge policy must be applied
Text: <span>@taxon.DisplayName</span>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 31
Reason: Botanical displayName used — badge policy must be applied
Text: p.DisplayName,

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 38
Reason: Botanical displayName used — badge policy must be applied
Text: DisplayName = grp.Key.DisplayName,

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 43
Reason: Botanical displayName used — badge policy must be applied
Text: .ThenBy(x => x.DisplayName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 50
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Taxon.cshtml
Line: 5
Reason: Botanical displayName used — badge policy must be applied
Text: ViewData["Title"] = Model.DisplayName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Taxon.cshtml
Line: 9
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Taxon.cshtml.cs
Line: 24
Reason: Botanical displayName used — badge policy must be applied
Text: public string DisplayName { get; private set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Taxon.cshtml.cs
Line: 38
Reason: Botanical displayName used — badge policy must be applied
Text: DisplayName = Plants.FirstOrDefault()?.DisplayName ?? string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Details.cshtml
Line: 24
Reason: Botanical displayName used — badge policy must be applied
Text: <dt class="col-sm-3 fw-bold">@Html.DisplayNameFor(m => m.Genus!.Name)</dt>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Details.cshtml
Line: 27
Reason: Botanical displayName used — badge policy must be applied
Text: <dt class="col-sm-3 fw-bold">@Html.DisplayNameFor(m => m.Genus!.Notes)</dt>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Locations\Index.cshtml
Line: 42
Reason: Botanical displayName used — badge policy must be applied
Text: @location.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 5
Reason: Botanical displayName used — badge policy must be applied
Text: @Model.Taxon!.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 25
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.Taxon!.GenusName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 32
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.Taxon!.SpeciesName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 40
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.Taxon!.HybridName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 46
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.Taxon!.GrowthNotes)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 53
Reason: Botanical displayName used — badge policy must be applied
Text: @Html.DisplayNameFor(m => m.Taxon!.TaxonNotes)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Index.cshtml
Line: 47
Reason: Botanical displayName used — badge policy must be applied
Text: @taxon.DisplayName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Index.cshtml.cs
Line: 29
Reason: Botanical displayName used — badge policy must be applied
Text: .ThenBy(t => t.DisplayName)

## GenusRender

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 46
Reason: Direct genusName usage — may require inactive badge support
Text: entity.Property(e => e.Name)                    .HasColumnName("genusName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 223
Reason: Direct genusName usage — may require inactive badge support
Text: entity.Property(e => e.GenusName)               .HasColumnName("genusName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Data\OrchidDbContext.cs
Line: 248
Reason: Direct genusName usage — may require inactive badge support
Text: entity.Property(e => e.GenusName)               .HasColumnName("genusName");

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\PlantActiveSummary.cs
Line: 14
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Models\TaxonIdentity.cs
Line: 11
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Add\Index.cshtml
Line: 20
Reason: Direct genusName usage — may require inactive badge support
Text: @foreach (var genusGroup in Model.Taxa.GroupBy(t => t.GenusName))

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Add\Index.cshtml.cs
Line: 27
Reason: Direct genusName usage — may require inactive badge support
Text: .OrderBy(t => t.GenusName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml
Line: 27
Reason: Direct genusName usage — may require inactive badge support
Text: @foreach (var genusGroup in Model.Taxa.GroupBy(t => t.GenusName))

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 32
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = g.Name

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 39
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = grp.Key.GenusName,

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 42
Reason: Direct genusName usage — may require inactive badge support
Text: .OrderBy(x => x.GenusName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Index.cshtml.cs
Line: 51
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 25
Reason: Direct genusName usage — may require inactive badge support
Text: <label asp-for="GenusName" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 29
Reason: Direct genusName usage — may require inactive badge support
Text: <input asp-for="GenusName"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 32
Reason: Direct genusName usage — may require inactive badge support
Text: <span asp-validation-for="GenusName"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml.cs
Line: 24
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml.cs
Line: 42
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName,

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml
Line: 30
Reason: Direct genusName usage — may require inactive badge support
Text: <option value="@g.GenusId">@g.GenusName</option>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml.cs
Line: 57
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = g.Name

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml.cs
Line: 131
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; set; } = "";

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 7
Reason: Direct genusName usage — may require inactive badge support
Text: @Model.GenusName

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 24
Reason: Direct genusName usage — may require inactive badge support
Text: public string GenusName { get; private set; } = string.Empty;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 48
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = g.Name

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 57
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = result.GenusName;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 66
Reason: Direct genusName usage — may require inactive badge support
Text: await ReloadGenusNameAsync(id);

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 85
Reason: Direct genusName usage — may require inactive badge support
Text: await ReloadGenusNameAsync(id);

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 92
Reason: Direct genusName usage — may require inactive badge support
Text: private async Task ReloadGenusNameAsync(int taxonId)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml.cs
Line: 94
Reason: Direct genusName usage — may require inactive badge support
Text: GenusName = await _db.Taxa

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 25
Reason: Direct genusName usage — may require inactive badge support
Text: @Html.DisplayNameFor(m => m.Taxon!.GenusName)

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Details.cshtml
Line: 27
Reason: Direct genusName usage — may require inactive badge support
Text: <dd class="col-sm-9">@Model.Taxon.GenusName</dd>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Index.cshtml
Line: 35
Reason: Direct genusName usage — may require inactive badge support
Text: @foreach (var genusGroup in Model.Taxa.GroupBy(t => t.GenusName))

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Index.cshtml.cs
Line: 28
Reason: Direct genusName usage — may require inactive badge support
Text: .OrderBy(t => t.GenusName)

## SelectionSurface

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 26
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="GenusId" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 32
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <select asp-for="GenusId"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 51
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input type="hidden" asp-for="GenusId" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 54
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="TaxonId" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 60
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <select asp-for="TaxonId"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 80
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input type="hidden" asp-for="GenusId" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml
Line: 81
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input type="hidden" asp-for="TaxonId" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 39
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: public SelectList GenusOptions { get; private set; } = default!;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 40
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: public SelectList TaxonOptions { get; private set; } = default!;

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 200
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: GenusOptions = new SelectList(genera, "GenusId", "Name", GenusId);

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Plants\Edit\Index.cshtml.cs
Line: 216
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: TaxonOptions = new SelectList(

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 25
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="GenusName" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 29
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input asp-for="GenusName"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 37
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="GenusNotes" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Add.cshtml
Line: 41
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <textarea asp-for="GenusNotes"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Edit.cshtml
Line: 22
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Genus.Name" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Edit.cshtml
Line: 26
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input asp-for="Genus.Name" class="form-control" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Edit.cshtml
Line: 32
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Genus.Notes" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Genera\Actions\Edit.cshtml
Line: 36
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <textarea asp-for="Genus.Notes"

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml
Line: 22
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="GenusId" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml
Line: 26
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <select class="form-select" asp-for="GenusId" required>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml
Line: 64
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="TaxonNotes" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Add.cshtml
Line: 68
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <textarea class="form-control" asp-for="TaxonNotes"></textarea>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 32
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Taxon.SpeciesName" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 36
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input asp-for="Taxon.SpeciesName" class="form-control" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 44
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Taxon.HybridName" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 48
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <input asp-for="Taxon.HybridName" class="form-control" />

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 54
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Taxon.GrowthNotes" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 58
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <textarea asp-for="Taxon.GrowthNotes" class="form-control"></textarea>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 63
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <label asp-for="Taxon.TaxonNotes" class="fw-bold"></label>

File: C:\Users\rfeen\source\repos\OrchidApp\src\OrchidApp.Web\Pages\Setup\Taxa\Actions\Edit.cshtml
Line: 67
Reason: Selection UI using taxonomy — inactive filtering rules must apply
Text: <textarea asp-for="Taxon.TaxonNotes" class="form-control"></textarea>

