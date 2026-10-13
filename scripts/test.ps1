param(
    [string]$GamePath='C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac='C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$build=Join-Path $repo '.build'
$mod=Join-Path $repo 'Contents/mods/PlayableSoccer/42'
New-Item -ItemType Directory -Force $build | Out-Null
$sources=@(Get-ChildItem (Join-Path $repo 'tests') -Filter '*.java' | ForEach-Object FullName)
& $Javac -cp (Join-Path $GamePath 'projectzomboid.jar') -d $build @sources
if($LASTEXITCODE -ne 0){throw 'Test compilation failed'}
$java=Join-Path $GamePath 'jre64/bin/java.exe'
$cp="$build;$(Join-Path $GamePath 'projectzomboid.jar')"
function Invoke-Lua([string[]]$Files) {
    & $java -cp $cp LuaHarness @Files
    if($LASTEXITCODE -ne 0){throw 'Kahlua test failed'}
}
Push-Location $GamePath
try {
    $core=Join-Path $mod 'media/lua/shared/PS_Core.lua'
    Invoke-Lua @($core,(Join-Path $repo 'tests/core.test.lua'))
    Invoke-Lua @((Join-Path $repo 'tests/server-bootstrap.lua'),$core,(Join-Path $mod 'media/lua/server/PS_Server.lua'),(Join-Path $repo 'tests/server.test.lua'))
    Invoke-Lua @((Join-Path $repo 'tests/conversion-bootstrap.lua'),(Join-Path $mod 'media/lua/shared/PS_ConvertBall.lua'),(Join-Path $mod 'media/lua/client/PS_BallMenu.lua'),(Join-Path $repo 'tests/conversion.test.lua'))
    Invoke-Lua @((Join-Path $repo 'tests/client-bootstrap.lua'),$core,(Join-Path $mod 'media/lua/client/PS_Render.lua'),(Join-Path $mod 'media/lua/client/PS_Client.lua'),(Join-Path $repo 'tests/client.test.lua'))
    foreach($name in @('NativeApiTest','RenderNativeTest')) {
        if(Test-Path (Join-Path $repo "tests/$name.java")) {
            & $java -cp $cp $name $mod
            if($LASTEXITCODE -ne 0){throw "Native check failed: $name"}
        }
    }
    $files=@(Get-ChildItem (Join-Path $mod 'media/lua') -Recurse -Filter '*.lua' | ForEach-Object FullName)
    & $java '-DcompileOnly=true' -cp $cp LuaHarness @files
    if($LASTEXITCODE -ne 0){throw 'Production Lua syntax failed'}
} finally { Pop-Location }
foreach($category in @('UI','ContextMenu','ItemName')) {
    $en=Get-Content (Join-Path $mod "media/lua/shared/Translate/EN/$category.json") -Raw | ConvertFrom-Json
    $ko=Get-Content (Join-Path $mod "media/lua/shared/Translate/KO/$category.json") -Raw | ConvertFrom-Json
    if(Compare-Object @($en.PSObject.Properties.Name) @($ko.PSObject.Properties.Name)){throw "Translation mismatch: $category"}
    foreach($property in $en.PSObject.Properties){if(-not $ko.($property.Name)){throw "Empty Korean translation: $($property.Name)"}}
}
Write-Output 'PASS soccer source checks and translation parity; not live gameplay proof'
