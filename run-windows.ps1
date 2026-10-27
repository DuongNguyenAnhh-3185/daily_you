param([switch]$Build)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$executable = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release\nhat_ky_viet.exe'
if ($Build -or -not (Test-Path -LiteralPath $executable)) {
    $flutterCommand = (Get-Command flutter.bat -ErrorAction Stop).Source
    & $flutterCommand pub get
    if ($LASTEXITCODE -ne 0) { throw 'Không thể cài thư viện Flutter.' }
    & $flutterCommand build windows --release --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Build Windows thất bại.' }
}
Start-Process -FilePath $executable -WorkingDirectory (Split-Path -Parent $executable)
