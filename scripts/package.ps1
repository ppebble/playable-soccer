param([switch]$Install,[string]$ModsPath=(Join-Path $env:USERPROFILE 'Zomboid/mods'))
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$source=Join-Path $repo 'Contents/mods/PlayableSoccer'
& (Join-Path $PSScriptRoot 'check-release.ps1') -ModRoot $source
$base=if($Install){[IO.Path]::GetFullPath($ModsPath)}else{Join-Path $repo '.stage/Contents/mods'}
if($base -match '(?i)steamapps[\\/]workshop'){throw 'Workshop content is read-only'}
New-Item -ItemType Directory -Force $base | Out-Null
$target=[IO.Path]::GetFullPath((Join-Path $base 'PlayableSoccer'))
if((Split-Path $target -Parent) -ne [IO.Path]::GetFullPath($base).TrimEnd('\','/')){throw 'Target escaped destination'}
if(Test-Path -LiteralPath $target){
    $info=Join-Path $target '42/mod.info'
    if(-not(Test-Path $info) -or (Get-Content $info -Raw) -notmatch '(?m)^id=PlayableSoccer\s*$'){throw 'Existing destination is not owned by this mod'}
    if((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Refuse linked destination'}
    $backup=[IO.Path]::GetFullPath((Join-Path $repo ('.build/backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'/PlayableSoccer')))
    if(-not $backup.StartsWith([IO.Path]::GetFullPath((Join-Path $repo '.build/backups'))+[IO.Path]::DirectorySeparatorChar)){throw 'Backup escaped repository'}
    New-Item -ItemType Directory -Force (Split-Path $backup -Parent) | Out-Null
    Move-Item -LiteralPath $target -Destination $backup
}
Copy-Item -LiteralPath $source -Destination $target -Recurse
$count=0
foreach($file in Get-ChildItem $source -File -Recurse -Force){
    $relative=$file.FullName.Substring($source.Length).TrimStart([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $target $relative)).Hash){throw "Hash mismatch: $relative"}
    $count++
}
Write-Output "PASS $count identical files at $target"
