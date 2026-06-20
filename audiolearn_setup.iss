#define MyAppName "AudioLearn"
#define MyAppVersion "3.4.8"
#define MyAppPublisher "Jean-Pierre Schnyder"
#define MyAppURL ""
#define MyAppExeName "audiolearn.exe"

[Setup]
AppId={{8F5DC1F8-7703-47D7-9795-E83916DB2FEF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\AudioLearn
; Require administrator privileges - prevents "install for me only" option
PrivilegesRequired=admin
; This removes the "install for me only" option
PrivilegesRequiredOverridesAllowed=
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
MinVersion=10.0
OutputDir=C:\Users\jpsch\Documents\AudioLearn\installer\Output
OutputBaseFilename=AudioLearn_Windows_Setup
SetupIconFile=C:\development\flutter\audiolearn\assets\icons\audiolearn_multi.ico
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "french";  MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\development\flutter\audiolearn\build\windows\x64\runner\Release\*"; \
  DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";  Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent