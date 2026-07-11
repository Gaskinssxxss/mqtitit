. "$PSScriptRoot\common.ps1"
Import-ProjectConfig

Write-Host "Peran      : Windows client, attacker uji, dan analisis"
Write-Host "Broker     : $($env:BROKER_HOST):$($env:MQTT_PORT)"
Write-Host "Scenario   : $($env:SCENARIO)"
Write-Host "Run ID     : $($env:RUN_ID)"

try {
    $python = Get-PythonCommand
    Write-Host "[OK] Python: $($python -join ' ')"
    Invoke-Python -Arguments @(
        "-c",
        "import paho.mqtt.client, pandas, numpy, scipy; print('[OK] Paket Python tersedia')"
    )
} catch {
    Write-Error $_
}

$reachable = Test-NetConnection -ComputerName $env:BROKER_HOST -Port ([int]$env:MQTT_PORT) -WarningAction SilentlyContinue
if ($reachable.TcpTestSucceeded) {
    Write-Host "[OK] Broker dapat diakses dari Windows."
} else {
    Write-Warning "Broker belum dapat diakses pada $($env:BROKER_HOST):$($env:MQTT_PORT)."
}

$nping = Get-Command nping -ErrorAction SilentlyContinue
if ($nping) {
    Write-Host "[OK] Nping tersedia untuk SYN flood dari Windows: $($nping.Source)"
} else {
    Write-Warning "Nping belum ditemukan. Install Nmap + Npcap jika Windows dipakai sebagai attacker SYN flood."
}
