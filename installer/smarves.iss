; L'installateur Windows de Smarves (Inno Setup 6), construit par le workflow « Exporter pour
; Windows » à partir de build/Smarves.exe. Installation pour l'utilisateur seul, sans droits
; administrateur, dans %LOCALAPPDATA%\Programs\Smarves, avec un raccourci dans le menu Démarrer,
; un sur le bureau (case cochée d'office) et un désinstallateur. Relancé sur une version déjà
; installée, il la remplace : même AppId, même dossier. Les parties sauvegardées vivent dans
; %APPDATA%\Godot\app_userdata\Smarves, hors du dossier installé : la désinstallation les garde.
;
; Construire à la main : iscc /DVersion=abc1234 installer\smarves.iss (depuis la racine du dépôt).

#ifndef Version
  #define Version "dev"
#endif

[Setup]
AppId={{6F3B0C52-8A0E-4B8D-9E1C-5D2A7C4E9B31}
AppName=Smarves
AppVersion={#Version}
AppVerName=Smarves ({#Version})
AppPublisher=Smarves
AppPublisherURL=https://github.com/chtabay/smarves
DefaultDirName={autopf}\Smarves
DefaultGroupName=Smarves
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\Smarves.exe
UninstallDisplayName=Smarves
CloseApplications=yes
SourceDir=..
OutputDir=build
OutputBaseFilename=Smarves-installateur
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=assets\icone\smarves.ico

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Mettre un raccourci sur le bureau"

[Files]
Source: "build\Smarves.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Smarves"; Filename: "{app}\Smarves.exe"
Name: "{autodesktop}\Smarves"; Filename: "{app}\Smarves.exe"; Tasks: bureau

[Run]
Filename: "{app}\Smarves.exe"; Description: "Lancer Smarves"; Flags: nowait postinstall skipifsilent
