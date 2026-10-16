param([string]$ModRoot=(Join-Path $PSScriptRoot '../Contents/mods/PlayableSoccer'))
$ErrorActionPreference='Stop'
$retired='zonesFor|zoneCapture|zoneShot|zonePass|testZones|tackleDiagnostic|diagnosticId|UI_PS_(TestZonesUnavailable|TackleZone|KeeperZone|ShooterZone|PasserZone|ZonePossession|ShooterPossession|PasserPossession)|PlayableSoccer motion v|PlayableSoccer tackle '
foreach($file in Get-ChildItem -LiteralPath $ModRoot -Recurse -File -Force){
    if($file.Extension -in @('.lua','.json','.xml','.info')) {
        if(Select-String -LiteralPath $file.FullName -Pattern $retired -Quiet){throw "Retired development feature in package: $($file.FullName)"}
    }
    if($file.FullName -match '[\\/](tests|\.build|\.omx)[\\/]'){throw "Development directory in package: $($file.FullName)"}
}
Write-Output 'PASS release content excludes test regions, virtual players and motion tracing'
