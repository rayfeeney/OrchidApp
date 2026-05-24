#define MyAppName "OrchidApp"
#define MyAppPublisher "OrchidApp"
#define MyAppExeName "OrchidApp.Launcher.exe"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif
#define SourceDir "..\..\dist\windows\OrchidApp"
#define OutputDir "..\..\dist\installer"

[Setup]
AppId={{A82E6156-7CAE-4186-9F33-9CF1A49F5CD8}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\OrchidApp
DefaultGroupName=OrchidApp
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=OrchidAppSetup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
ConfirmUninstall=This will uninstall OrchidApp application files only.%n%nYour plant database, uploaded photos, backups and settings under C:\ProgramData\OrchidApp will not be deleted.%n%nDo you want to continue?

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "data\*,wwwroot\uploads\*,uploads\*,backups\*,logs\*,launcher.log,launcher-settings.json,migration-state.json"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\OrchidApp"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\OrchidApp"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch OrchidApp"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Intentionally empty.
; User data lives under C:\ProgramData\OrchidApp and must not be deleted by the app uninstaller.