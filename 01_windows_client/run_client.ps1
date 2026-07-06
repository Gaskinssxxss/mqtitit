. "$PSScriptRoot\common.ps1"
Import-ProjectConfig

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
