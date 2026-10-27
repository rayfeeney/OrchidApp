#define MyAppName "OrchidApp"
#define MyAppPublisher "OrchidApp"
#define MyAppExeName "OrchidApp.Launcher.exe"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\dist\windows\OrchidApp"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist\installer"
#endif

[Setup]
#ifdef InstallerFixture
; Test builds use an unrelated product identity and never touch ProgramData.
AppId={#FixtureAppId}
#else
AppId={{A82E6156-7CAE-4186-9F33-9CF1A49F5CD8}}
#endif
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
#ifdef InstallerFixture
PrivilegesRequired=lowest
#else
PrivilegesRequired=admin
#endif
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName} {#MyAppVersion}
UninstallDisplayIcon={app}\OrchidApp.Launcher.exe
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
ConfirmUninstall=This will uninstall OrchidApp application files only.%n%nYour plant database, uploaded photos, backups and settings under C:\ProgramData\OrchidApp will not be deleted.%n%nDo you want to continue?

[Files]
Source: "..\..\app\tools\prepare-installer-upgrade.ps1"; Flags: dontcopy noencryption
Source: "..\..\app\tools\Installer-Snapshot.ps1"; Flags: dontcopy noencryption
#ifdef InstallerFixture
Source: "..\..\tests\InstallerUpgrade.Checks\PrepareFixture.ps1"; Flags: dontcopy noencryption
#endif
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "data\*,wwwroot\uploads\*,uploads\*,backups\*,logs\*,launcher.log,launcher-settings.json,migration-state.json"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
#ifndef InstallerFixture
Name: "{group}\OrchidApp"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\OrchidApp"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Run]
#ifndef InstallerFixture
Filename: "{app}\{#MyAppExeName}"; Description: "Launch OrchidApp"; Flags: nowait postinstall skipifsilent
#endif

[UninstallDelete]
; Intentionally empty.
; User data lives under C:\ProgramData\OrchidApp and must not be deleted by the app uninstaller.

[Code]
function GetCurrentProcessId: LongWord;
  external 'GetCurrentProcessId@kernel32.dll stdcall';

function QuoteArgument(Value: String): String;
begin
  Result := '"' + Value + '"';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
  PersistentRoot, ResultFile, Arguments, MessageText, PrepareScript: String;
  ResultText: AnsiString;
begin
  Result := '';
  ExtractTemporaryFile('prepare-installer-upgrade.ps1');
  ExtractTemporaryFile('Installer-Snapshot.ps1');
#ifdef InstallerFixture
  PersistentRoot := '{#FixturePersistentRoot}';
  ExtractTemporaryFile('PrepareFixture.ps1');
  PrepareScript := ExpandConstant('{tmp}\PrepareFixture.ps1');
#else
  PersistentRoot := ExpandConstant('{commonappdata}\OrchidApp');
  PrepareScript := ExpandConstant('{tmp}\prepare-installer-upgrade.ps1');
#endif
  ResultFile := ExpandConstant('{tmp}\orchidapp-upgrade-result.txt');
  Arguments := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ' +
    QuoteArgument(PrepareScript) +
    ' -AppRoot ' + QuoteArgument(ExpandConstant('{app}')) +
    ' -PersistentRoot ' + QuoteArgument(PersistentRoot) +
    ' -ResultFile ' + QuoteArgument(ResultFile) +
    ' -InstallerProcessId ' + IntToStr(GetCurrentProcessId);
  WizardForm.StatusLabel.Caption := 'Checking stopped applications and creating a verified recovery snapshot...';
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      Arguments, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then begin
    Result := 'The pre-install recovery check could not run. No application files were replaced.';
    Exit;
  end;
  MessageText := 'The pre-install recovery check failed. Close OrchidApp and its database, preserve recovery files and obtain support.';
  if LoadStringFromFile(ResultFile, ResultText) then
    MessageText := UTF8Decode(ResultText);
  Log(MessageText);
  if ExitCode <> 0 then
    Result := MessageText;
end;
