param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [string]$ServerAHost = "192.168.56.10",
    [string]$ServerAUser = "server-a",
    [string]$ServerAProject = "~/mqtitit/02_ubuntu_server_a_broker",

    [string]$ServerBHost = "192.168.56.20",
    [string]$ServerBUser = "server-b",
    [string]$ServerBProject = "~/mqtitit/03_ubuntu_server_b_attacker",

    [switch]$SkipServerB,
    [switch]$IncludeServerB
)

$ErrorActionPreference = "Stop"

$scp = Get-Command scp -ErrorAction SilentlyContinue
if (-not $scp) {
    throw "scp tidak ditemukan di Windows. Install/OpenSSH Client dulu."
}

function Copy-RemoteFile {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [Parameter(Mandatory = $true)][string]$LocalDirectory,
        [switch]$Optional
    )

    New-Item -ItemType Directory -Force -Path $LocalDirectory | Out-Null
    $source = "${Target}:$RemotePath"
    Write-Host "[COPY] $source"
    Write-Host "       -> $LocalDirectory"
    & $scp.Source $source $LocalDirectory
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) {
            Write-Warning "File optional tidak berhasil dicopy: $source"
            return
        }
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

Write-Host "========================================"
Write-Host "COLLECT HASIL EKSPERIMEN"
Write-Host "Run ID   : $RunId"
Write-Host "Server A : $serverATarget"
if ($IncludeServerB) {
    Write-Host "Server B : $serverBTarget"
} else {
    Write-Host "Server B : tidak digunakan"
}
Write-Host "Output   : $runDirectory"
Write-Host "========================================"

Write-Host "[COPY] Mengambil hasil Server A."
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/metadata.env" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/capture.log" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/capture.pcapng" -LocalDirectory $serverADirectory
Copy-RemoteFile -Target $serverATarget -RemotePath "$serverAProjectRemote/experiments/$RunId/raw_flow.csv" -LocalDirectory $serverADirectory

Copy-Item -Force (Join-Path $serverADirectory "metadata.env") (Join-Path $runDirectory "metadata.env")
Copy-Item -Force (Join-Path $serverADirectory "raw_flow.csv") (Join-Path $runDirectory "raw_flow.csv")

if ($IncludeServerB -and -not $SkipServerB) {
    Write-Host "[COPY] Mengambil hasil Server B."
    Copy-RemoteFile -Target $serverBTarget -RemotePath "$serverBProjectRemote/experiments/$RunId/attack.log" -LocalDirectory $serverBDirectory
}

$localAttackLog = Join-Path $runDirectory "attack.log"
if (Test-Path $localAttackLog) {
    $windowsAttackDirectory = Join-Path $runDirectory "windows_attacker"
    New-Item -ItemType Directory -Force -Path $windowsAttackDirectory | Out-Null
    Copy-Item -Force $localAttackLog $windowsAttackDirectory
}

Write-Host "[OK] File mentah sudah dikumpulkan ke:"
Write-Host "     $runDirectory"
Write-Host "[INFO] File utama:"
Write-Host "     mqtt_client.csv"
Write-Host "     metadata.env"
Write-Host "     raw_flow.csv"
Write-Host "     server_a_broker\capture.pcapng"
if (Test-Path $localAttackLog) {
    Write-Host "     attack.log"
    Write-Host "     windows_attacker\attack.log"
}
if ($IncludeServerB -and -not $SkipServerB) {
    Write-Host "     server_b_attacker\attack.log"
}
