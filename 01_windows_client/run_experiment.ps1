param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("normal", "syn_flood", "syn_flood_rate_limit")]
    [string]$Scenario,

    [string]$RunId,
    [string]$BrokerHost = "192.168.56.10",
    [int]$Duration = 60,
    [int]$CaptureDuration = 75,
    [string]$BrokerIface = "enp0s8",
    [int]$AttackRate = 1000,

    [string]$ServerAHost = "192.168.56.10",
    [string]$ServerAUser = "server-a",
    [string]$ServerAProject = "~/mqtitit/02_ubuntu_server_a_broker",

    [string]$ServerBHost = "192.168.56.20",
    [string]$ServerBUser = "server-b",
    [string]$ServerBProject = "~/mqtitit/03_ubuntu_server_b_attacker",

    [int]$StartDelaySeconds = 5
)

$ErrorActionPreference = "Stop"

if (-not $RunId) {
    $RunId = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_$Scenario"
}

$ssh = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $ssh) {
    throw "ssh tidak ditemukan di Windows. Install/OpenSSH Client dulu."
}
$scp = Get-Command scp -ErrorAction SilentlyContinue
if (-not $scp) {
    throw "scp tidak ditemukan di Windows. Install/OpenSSH Client dulu."
}

function Invoke-SshCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Command
    )

    Write-Host "[SSH] $Target"
    Write-Host "      $Command"
    ssh -tt $Target $Command
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command gagal pada $Target dengan kode $LASTEXITCODE."
    }
}

function Start-SshCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Name
    )

    Write-Host "[START] $Name pada $Target"
    Write-Host "        $Command"
    return Start-Process `
        -FilePath $ssh.Source `
        -ArgumentList @("-tt", $Target, $Command) `
        -NoNewWindow `
        -PassThru
}

function Copy-RemoteFile {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [Parameter(Mandatory = $true)][string]$LocalDirectory
    )

    New-Item -ItemType Directory -Force -Path $LocalDirectory | Out-Null
    $source = "${Target}:$RemotePath"
    Write-Host "[COPY] $source"
    Write-Host "       -> $LocalDirectory"
    & $scp.Source $source $LocalDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal copy $source ke $LocalDirectory dengan kode $LASTEXITCODE."
    }
}

$serverATarget = "$ServerAUser@$ServerAHost"
$serverBTarget = "$ServerBUser@$ServerBHost"
$serverAProjectRemote = $ServerAProject.Replace("~", "/home/$ServerAUser")
$serverBProjectRemote = $ServerBProject.Replace("~", "/home/$ServerBUser")
$runDirectory = Join-Path (Join-Path $PSScriptRoot "experiments") $RunId
$serverADirectory = Join-Path $runDirectory "server_a_broker"
$serverBDirectory = Join-Path $runDirectory "server_b_attacker"

$brokerCommand = "cd $serverAProjectRemote && sudo -v && ./scripts/run_broker.sh --scenario $Scenario --run-id $RunId --broker-host $BrokerHost --iface $BrokerIface --duration $Duration --capture-duration $CaptureDuration"
$clientCommand = @(
    "-ExecutionPolicy", "Bypass",
    "-File", ".\run_client.ps1",
    "-Scenario", $Scenario,
    "-RunId", $RunId,
    "-BrokerHost", $BrokerHost,
    "-Duration", "$Duration"
)
$attackerCommand = "cd $serverBProjectRemote && sudo -v && ./scripts/run_attacker.sh --scenario $Scenario --run-id $RunId --broker-host $BrokerHost --duration $Duration --attack-rate $AttackRate --yes-local"
$finalizeCommand = "cd $serverAProjectRemote && ./scripts/finalize_broker.sh"

Write-Host "========================================"
Write-Host "RUN EKSPERIMEN MQTT"
Write-Host "Scenario       : $Scenario"
Write-Host "Run ID         : $RunId"
Write-Host "Broker         : $BrokerHost"
Write-Host "Server A       : $serverATarget"
Write-Host "Server B       : $serverBTarget"
Write-Host "Broker iface   : $BrokerIface"
Write-Host "Duration       : $Duration detik"
Write-Host "Capture        : $CaptureDuration detik"
Write-Host "Attack rate    : $AttackRate paket/detik"
Write-Host "========================================"

Write-Host "[INFO] Cek SSH ke Server A."
Invoke-SshCommand -Target $serverATarget -Command "echo server-a-ok"

if ($Scenario -ne "normal") {
    Write-Host "[INFO] Cek SSH ke Server B."
    Invoke-SshCommand -Target $serverBTarget -Command "echo server-b-ok"
}

$brokerProcess = Start-SshCommand -Target $serverATarget -Command $brokerCommand -Name "broker-capture"
Start-Sleep -Seconds $StartDelaySeconds

if ($Scenario -ne "normal") {
    $attackerProcess = Start-SshCommand -Target $serverBTarget -Command $attackerCommand -Name "attacker"
    Start-Sleep -Seconds 2
}

Write-Host "[RUN] Windows client"
& powershell @clientCommand
if ($LASTEXITCODE -ne 0) {
    throw "Windows client gagal dengan kode $LASTEXITCODE."
}

if ($Scenario -ne "normal" -and $attackerProcess) {
    Write-Host "[WAIT] Menunggu attacker Server B selesai."
    $attackerProcess.WaitForExit()
    if ($attackerProcess.ExitCode -ne 0) {
        throw "Attacker gagal dengan kode $($attackerProcess.ExitCode)."
    }
}

Write-Host "[WAIT] Menunggu capture Server A selesai."
$brokerProcess.WaitForExit()
if ($brokerProcess.ExitCode -ne 0) {
    throw "Broker/capture gagal dengan kode $($brokerProcess.ExitCode)."
}

Write-Host "[RUN] Finalize capture di Server A."
Invoke-SshCommand -Target $serverATarget -Command $finalizeCommand

Write-Host "[COPY] Mengambil hasil Server A ke Windows."
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/metadata.env" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/capture.log" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/capture.pcapng" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/raw_flow.csv" -LocalDirectory $serverADirectory

Copy-Item -Force (Join-Path $serverADirectory "metadata.env") (Join-Path $runDirectory "metadata.env")
Copy-Item -Force (Join-Path $serverADirectory "raw_flow.csv") (Join-Path $runDirectory "raw_flow.csv")

if ($Scenario -ne "normal") {
    Write-Host "[COPY] Mengambil hasil Server B ke Windows."
    Copy-RemoteFile -Target $serverBTarget -RemotePath "$serverBProjectRemote/experiments/$RunId/attack.log" -LocalDirectory $serverBDirectory
}

Write-Host "[OK] Eksperimen selesai."
Write-Host "[INFO] Hasil sudah dikumpulkan ke:"
Write-Host "       Windows : experiments\$RunId\mqtt_client.csv"
Write-Host "       Server A: experiments\$RunId\server_a_broker\"
if ($Scenario -ne "normal") {
    Write-Host "       Server B: experiments\$RunId\server_b_attacker\attack.log"
}
Write-Host "[INFO] Untuk analisis satu run, jalankan:"
Write-Host "       powershell -ExecutionPolicy Bypass -File .\analyze_run.ps1 -RunId $RunId"
