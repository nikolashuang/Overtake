param([Parameter(Mandatory=$true)][string]$Luau)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$bundle = Get-Content (Join-Path $PSScriptRoot 'engine-mock.luau') -Raw
$modules = @(
    @('Config','src/shared/Parkour/ParkourConfig.luau'),
    @('State','src/shared/Simulation/MovementState.luau'),
    @('Detection','src/shared/Parkour/ParkourDetection.luau'),
    @('CharacterClass','src/shared/Character/CharacterClass.luau'),
    @('Inputs','src/shared/Simulation/MovementInputs.luau'),
    @('Simulation','src/shared/Simulation/MovementSimulation.luau'),
    @('Diagnostics','src/shared/Simulation/MovementDiagnostics.luau')
)
foreach ($module in $modules) {
    $source = Get-Content (Join-Path $root $module[1]) -Raw
    # Dependency injection only: execute the actual production source bodies.
    $source = [regex]::Replace($source, 'local Config = require\([^\r\n]+\)', 'local Config = Config')
    $source = [regex]::Replace($source, 'local ParkourConfig = require\([^\r\n]+\)', 'local ParkourConfig = Config')
    $source = [regex]::Replace($source, 'local MovementState = require\([^\r\n]+\)', 'local MovementState = State')
    $source = [regex]::Replace($source, 'local State = require\([^\r\n]+\)', 'local State = State')
    $source = [regex]::Replace($source, 'local ParkourDetection = require\([^\r\n]+\)', 'local ParkourDetection = Detection')
    $source = [regex]::Replace($source, 'local Detection = require\([^\r\n]+\)', 'local Detection = Detection')
    $source = [regex]::Replace($source, 'local CharacterClass = require\([^\r\n]+\)', 'local CharacterClass = CharacterClass')
    $source = [regex]::Replace($source, 'local Inputs = require\([^\r\n]+\)', 'local Inputs = Inputs')
    $bundle += "`nlocal $($module[0]) = (function()`n$source`nend)()`n"
}
$bundle += Get-Content (Join-Path $PSScriptRoot 'movement.spec.luau') -Raw
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) 'overtake-native-tests.luau'
Set-Content -LiteralPath $temporary -Value $bundle
& $Luau $temporary
if ($LASTEXITCODE -ne 0) { throw 'Movement regression tests failed' }
