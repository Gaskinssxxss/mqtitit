$ErrorActionPreference = "Stop"

$script:ProjectRoot = $PSScriptRoot

function Import-ProjectConfig {
    $configPath = Join-Path $script:ProjectRoot "config.env"
    if (-not (Test-Path $configPath)) {
        $configPath = Join-Path $script:ProjectRoot "config.env.example"
        Write-Warning "config.env belum ada; menggunakan config.env.example"
    }

    foreach ($line in Get-Content $configPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#") -or -not $trimmed.Contains("=")) {
            continue
        }
        $parts = $trimmed.Split("=", 2)
        [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }

    $defaults = @{
        RUN_ID = "run01_normal"
        SCENARIO = "normal"
        EXPERIMENT_DURATION = "60"
        DEPLOYMENT_MODE = "local"
        BROKER_HOST = "192.168.56.10"
        MQTT_PORT = "1883"
        MQTT_TOPIC = "unram/iot/suhu"
        MQTT_CLIENT_ID_PREFIX = "unram-test"
        MQTT_QOS = "1"
        MQTT_INTERVAL_MS = "1000"
        MQTT_TIMEOUT_SEC = "5"
        OUTPUT_DIR = "experiments"
    }
    foreach ($entry in $defaults.GetEnumerator()) {
        if (-not [Environment]::GetEnvironmentVariable($entry.Key, "Process")) {
            [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
        }
    }

    $validScenarios = @("normal", "syn_flood", "syn_flood_rate_limit")
    if ($env:SCENARIO -notin $validScenarios) {
        throw "SCENARIO tidak valid: $($env:SCENARIO). Pilih normal, syn_flood, atau syn_flood_rate_limit."
    }

    $validModes = @("local", "campus", "public")
    if ($env:DEPLOYMENT_MODE -notin $validModes) {
        throw "DEPLOYMENT_MODE tidak valid: $($env:DEPLOYMENT_MODE). Pilih local, campus, atau public."
    }
}

function Get-PythonCommand {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @("py", "-3")
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        return @("python")
    }
    throw "Python tidak ditemukan. Install Python 3 dan aktifkan pilihan Add Python to PATH."
}

function Invoke-Python {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $python = Get-PythonCommand
    if ($python.Count -eq 2) {
        & $python[0] $python[1] @Arguments
    } else {
        & $python[0] @Arguments
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Program Python berhenti dengan kode $LASTEXITCODE."
    }
}

function Get-RunDirectory {
    return Join-Path (Join-Path $script:ProjectRoot $env:OUTPUT_DIR) $env:RUN_ID
}
