[Setup]
AppName=Movie Easy
AppVersion=1.0.0
DefaultDirName={autopf}\Movie Easy
DefaultGroupName=Movie Easy
OutputDir=build\installer
OutputBaseFilename=MovieEasy_Setup
Compression=lzma
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\movie_easy.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copia o executável principal
Source: "build\windows\x64\runner\Release\movie_easy.exe"; DestDir: "{app}"; Flags: ignoreversion
; Copia todas as DLLs e pastas auxiliares (data, plugins, etc.)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "movie_easy.exe"

[Icons]
Name: "{group}\Movie Easy"; Filename: "{app}\movie_easy.exe"
Name: "{group}\{cm:UninstallProgram,Movie Easy}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Movie Easy"; Filename: "{app}\movie_easy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\movie_easy.exe"; Description: "{cm:LaunchProgram,Movie Easy}"; Flags: nowait postinstall skipifsilent