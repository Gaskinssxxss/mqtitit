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

$serverATarget = "$ServerAUser@$ServerAHost"
$serverBTarget = "$ServerBUser@$ServerBHost"

$brokerCommand = "cd $ServerAProject && sudo -v && ./scripts/run_broker.sh --scenario $Scenario --run-id $RunId --broker-host $BrokerHost --iface $BrokerIface --duration $Duration --capture-duration $CaptureDuration"
$clientCommand = @(
    "-ExecutionPolicy", "Bypass",
    "-File", ".\run_client.ps1",
    "-Scenario", $Scenario,
    "-RunId", $RunId,
    "-BrokerHost", $BrokerHost,
    "-Duration", "$Duration"
)
$attackerCommand = "cd $ServerBProject && sudo -v && ./scripts/run_attacker.sh --scenario $Scenario --run-id $RunId --broker-host $BrokerHost --duration $Duration --attack-rate $AttackRate --yes-local"
$finalizeCommand = "cd $ServerAProject && ./scripts/finalize_broker.sh"

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
Write-Host "[INFO] Cek sudo Server A untuk capture/rate limiting."
Invoke-SshCommand -Target $serverATarget -Command "sudo -v"

if ($Scenario -ne "normal") {
    Write-Host "[INFO] Cek SSH ke Server B."
    Invoke-SshCommand -Target $serverBTarget -Command "echo server-b-ok"
    Write-Host "[INFO] Cek sudo Server B untuk hping3."
    Invoke-SshCommand -Target $serverBTarget -Command "sudo -v"
}

$brokerProcess = Start-SshCommand -Target $serverATarget -Command $brokerCommand -Name "broker-capture"
Start-Sleep -Seconds $StartDelaySeconds

Write-Host "[RUN] Windows client"
& powershell @clientCommand
if ($LASTEXITCODE -ne 0) {
    throw "Windows client gagal dengan kode $LASTEXITCODE."
}

if ($Scenario -ne "normal") {
    $attackerProcess = Start-SshCommand -Target $serverBTarget -Command $attackerCommand -Name "attacker"
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

Write-Host "[OK] Eksperimen selesai."
Write-Host "[INFO] Ambil hasil dari:"
Write-Host "       Windows : experiments\$RunId\mqtt_client.csv"
Write-Host "       Server A: $ServerAProject/experiments/$RunId/"
if ($Scenario -ne "normal") {
    Write-Host "       Server B: $ServerBProject/experiments/$RunId/attack.log"
}
