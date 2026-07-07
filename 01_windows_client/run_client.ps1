param(
    [ValidateSet("normal", "syn_flood", "syn_flood_rate_limit")]
    [string]$Scenario,
    [string]$RunId,
    [string]$BrokerHost,
    [int]$MqttPort,
    [int]$Duration
)

. "$PSScriptRoot\common.ps1"
Import-ProjectConfig

if ($Scenario) {
    [Environment]::SetEnvironmentVariable("SCENARIO", $Scenario, "Process")
    if (-not $RunId) {
        $RunId = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_$Scenario"
    }
}
if ($RunId) {
    [Environment]::SetEnvironmentVariable("RUN_ID", $RunId, "Process")
}
if ($BrokerHost) {
    [Environment]::SetEnvironmentVariable("BROKER_HOST", $BrokerHost, "Process")
}
if ($MqttPort) {
    [Environment]::SetEnvironmentVariable("MQTT_PORT", "$MqttPort", "Process")
}
if ($Duration) {
    [Environment]::SetEnvironmentVariable("EXPERIMENT_DURATION", "$Duration", "Process")
}

$runDirectory = Get-RunDirectory
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$outputFile = Join-Path $runDirectory "mqtt_client.csv"

Write-Host "[INFO] Windows MQTT client"
Write-Host "[INFO] broker   : $($env:BROKER_HOST):$($env:MQTT_PORT)"
Write-Host "[INFO] scenario : $($env:SCENARIO)"
Write-Host "[INFO] run ID   : $($env:RUN_ID)"
Write-Host "[INFO] output   : $outputFile"

$arguments = @(
    (Join-Path $PSScriptRoot "src\mqtt_test_client.py"),
    "--broker-host", $env:BROKER_HOST,
    "--mqtt-port", $env:MQTT_PORT,
    "--topic", $env:MQTT_TOPIC,
    "--qos", $env:MQTT_QOS,
    "--interval-ms", $env:MQTT_INTERVAL_MS,
    "--timeout-sec", $env:MQTT_TIMEOUT_SEC,
    "--duration", $env:EXPERIMENT_DURATION,
    "--scenario", $env:SCENARIO,
    "--run-id", $env:RUN_ID,
    "--client-id-prefix", $env:MQTT_CLIENT_ID_PREFIX,
    "--output", $outputFile
)
Invoke-Python -Arguments $arguments
