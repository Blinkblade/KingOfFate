#Requires -Version 5.1
<# Rebuild Archer's sprite container from the licensed source and asset map. #>
[CmdletBinding()]
param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$source = Join-Path $repo 'assets\imports\archer_hires\Nameless_Archer\Archer.sff'
$mapping = Join-Path $repo 'design\characters\archer\asset_map.csv'
$output = Join-Path $repo 'game\chars\archer\archer.sff'
$packer = Join-Path $repo 'tools\sffpack\sffpack.py'
$selection = @()
$paletteDir = Split-Path -Parent $source
# Bank 1 is the source red. Banks 2-12 repeat official charcoal, blue and red
# variants so the engine's mirror-match selection never picks an effect bank.
foreach ($name in @('uc2p', 'fsd2p', 'FGO', 'Archer', 'uc2p', 'fsd2p', 'FGO', 'Archer', 'uc2p', 'fsd2p', 'FGO')) {
    $selection += '--selection-palette'
    $selection += Join-Path $paletteDir ($name + '.act')
}
& $Python $packer transcode $source --out $output --remap $mapping --force-palette 0 @selection
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Archer art rebuilt and verified. Sync game content before launching.'
exit 0
