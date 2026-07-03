; KeeVault Inno Setup Script
; Usage: iscc.exe /DAPP_VERSION=0.5.9 /DSOURCE_DIR=..\..\build\windows\x64\runner\Release keevault.iss

#ifndef SOURCE_DIR
  #define SOURCE_DIR "..\..\build\windows\x64\runner\Release"
#endif

#ifndef APP_VERSION
  #define APP_VERSION "0.0.0"
#endif

#define APP_NAME "KeeVault"
#define APP_PUBLISHER "KeeVault"
#define APP_URL "https://github.com/lyj404/keevault"
#define APP_EXE_NAME "keevault.exe"

[Setup]
AppId={{B2A1D3E4-5F6C-7D8E-9A0B-1C2D3E4F5A6B}
AppName={#APP_NAME}
AppVersion={#APP_VERSION}
AppPublisher={#APP_PUBLISHER}
AppPublisherURL={#APP_URL}
AppSupportURL={#APP_URL}/issues
DefaultDirName={autopf}\{#APP_NAME}
DefaultGroupName={#APP_NAME}
LicenseFile=..\..\LICENSE
OutputDir=..\..\build\windows\installer
OutputBaseFilename=KeeVault-v{#APP_VERSION}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#APP_EXE_NAME}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SOURCE_DIR}\{#APP_EXE_NAME}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SOURCE_DIR}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SOURCE_DIR}\kreepto.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SOURCE_DIR}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SOURCE_DIR}\*.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#APP_NAME}"; Filename: "{app}\{#APP_EXE_NAME}"
Name: "{group}\{cm:UninstallProgram,{#APP_NAME}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#APP_NAME}"; Filename: "{app}\{#APP_EXE_NAME}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#APP_EXE_NAME}"; Description: "{cm:LaunchProgram,{#StringChange(APP_NAME, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
