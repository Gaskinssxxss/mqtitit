. "$PSScriptRoot\common.ps1"
Import-ProjectConfig

$runDirectory = Get-RunDirectory
if (-not (Test-Path $runDirectory)) {
    throw "Folder pengujian tidak ditemukan: $runDirectory"
}

$arguments = @(
    (Join-Path $PSScriptRoot "src\analyze_single_run.py"),
    "--run-dir", $runDirectory
)
Invoke-Python -Arguments $arguments
