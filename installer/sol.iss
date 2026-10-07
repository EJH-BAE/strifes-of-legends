#define MyAppName "Strifes of Legends"
#define MyAppVersion "0.6.2"
#define MyAppPublisher "EJH-BAE"
#define MyAppURL "https://github.com/EJH-BAE/strifes-of-legends"

[Setup]
AppId={{8F4C2A91-6B17-4E5D-9A30-1C7D6E5B4A28}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName=C:\Strifes of Legends
DefaultGroupName=Strifes of Legends
DisableProgramGroupPage=yes
OutputDir=C:\Strifes of Legends\installer\out
OutputBaseFilename=SoLSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
CloseApplications=yes
CloseApplicationsFilter=Strifes of Legends.exe,Strife Manager.exe
UninstallDisplayIcon={app}\Strife Manager.exe
UninstallDisplayName=Strifes of Legends

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Files]
Source: "C:\Strifes of Legends\Strifes of Legends.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Strifes of Legends\Strife Manager.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Strife Manager"; Filename: "{app}\Strife Manager.exe"
Name: "{group}\Strifes of Legends"; Filename: "{app}\Strifes of Legends.exe"
Name: "{autodesktop}\Strife Manager"; Filename: "{app}\Strife Manager.exe"
Name: "{autodesktop}\Strifes of Legends"; Filename: "{app}\Strifes of Legends.exe"

[Run]
Filename: "{app}\Strife Manager.exe"; Description: "Strife Manager 실행"; Flags: nowait postinstall skipifsilent
