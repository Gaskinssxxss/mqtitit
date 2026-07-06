. "$PSScriptRoot\common.ps1"
Import-ProjectConfig

$arguments = @(
    (Join-Path $PSScriptRoot "src\analyze_all_runs.py"),
    "--experiments-dir", (Join-Path $PSScriptRoot $env:OUTPUT_DIR),
    "--output-dir", (Join-Path $PSScriptRoot "metrics")
)
Invoke-Python -Arguments $arguments
