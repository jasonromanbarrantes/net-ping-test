
Param(
  [ValidateSet("IC","Linc")][string]$TestType="IC",
  [int]$DurationMinutes=15
)

$ErrorActionPreference = "Stop"

$targets = if ($TestType -eq "IC") { @("216.20.237.2","216.20.235.2") } else { @("216.20.237.3","216.20.235.3") }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workdir = Join-Path $env:TEMP "pingtest_$timestamp"
New-Item -ItemType Directory -Path $workdir | Out-Null

# Optional: provenance files to prove test ran on this machine
try {
  $hostInfo = @{
    ComputerName   = $env:COMPUTERNAME
    User           = $env:USERNAME
    LocalIPv4      = (Get-NetIPConfiguration | ?{$_.IPv4DefaultGateway} | %{$_.IPv4Address.IPAddress}) -join ", "
    DefaultGateway = (Get-NetIPConfiguration | ?{$_.IPv4DefaultGateway} | %{$_.IPv4DefaultGateway.NextHop}) -join ", "
  }
  try { $hostInfo.PublicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip } catch {}
  $hostInfo | ConvertTo-Json | Set-Content (Join-Path $workdir "hostinfo.json")
} catch {}

# ~1 ping/sec for DurationMinutes
$count = [Math]::Round($DurationMinutes * 60)
$jobs = @()

foreach ($ip in $targets) {
  $outfile = Join-Path $workdir ("ping_{0}_raw.txt" -f $ip)
  $args = "-n $count $ip"

  $job = Start-Job -ScriptBlock {
    Param($args, $outfile)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ping.exe"
    $psi.Arguments = $args
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    Set-Content -Path $outfile -Value $out -Encoding UTF8
  } -ArgumentList $args, $outfile

  $jobs += $job
}

Write-Host "Running ping for $DurationMinutes minute(s) to $($targets -join ', ') ..." -ForegroundColor Cyan
Wait-Job -Job $jobs | Out-Null
Receive-Job -Job $jobs | Out-Null
$jobs | Remove-Job

# Build summary
$summary = @()
$lossRegex = [regex]"Packets: Sent = (\d+), Received = (\d+), Lost = (\d+) \((\d+)% loss\)"
$rttRegex  = [regex]"Minimum = (\d+)ms, Maximum = (\d+)ms, Average = (\d+)ms"

foreach ($ip in $targets) {
  $rawPath = Join-Path $workdir ("ping_{0}_raw.txt" -f $ip)
  $raw = Get-Content $rawPath -Raw

  $obj = [ordered]@{
    ip = $ip; sent=$null; received=$null; lost=$null; lossPct=$null; minMs=$null; maxMs=$null; avgMs=$null
  }

  $lm = $lossRegex.Match($raw)
  if ($lm.Success) {
    $obj.sent     = [int]$lm.Groups[1].Value
    $obj.received = [int]$lm.Groups[2].Value
    $obj.lost     = [int]$lm.Groups[3].Value
    $obj.lossPct  = [int]$lm.Groups[4].Value
  }
  $rm = $rttRegex.Match($raw)
  if ($rm.Success) {
    $obj.minMs = [int]$rm.Groups[1].Value
    $obj.maxMs = [int]$rm.Groups[2].Value
    $obj.avgMs = [int]$rm.Groups[3].Value
  }

  $summary += [pscustomobject]$obj
}

$summaryPath = Join-Path $workdir "summary.json"
$summary | ConvertTo-Json | Set-Content -Path $summaryPath -Encoding UTF8

# Zip everything
$zipPath = Join-Path $workdir "results.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$workdir\*" -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Done. Outputs are in: $workdir" -ForegroundColor Green
Write-Host " - Raw files: ping_<ip>_raw.txt"
Write-Host " - Summary:   summary.json"
Write-Host " - ZIP:       results.zip"
