
Param(
  [Parameter(Mandatory=$true)][string]$Ip,
  [int]$DurationSeconds=900
)
$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workdir = Join-Path $env:TEMP ("pingtest_"+$timestamp)
New-Item -ItemType Directory -Path $workdir -Force | Out-Null
$rawPath = Join-Path $workdir ("ping_"+$Ip+"_raw.txt")
$count = [Math]::Round($DurationSeconds)
Write-Host "Pinging $Ip for $count seconds (~1 pkt/sec)..." -ForegroundColor Cyan
ping.exe -n $count $Ip | Tee-Object -FilePath $rawPath
$raw = Get-Content $rawPath -Raw
$lossRegex = [regex]"Packets: Sent = (\d+), Received = (\d+), Lost = (\d+) \((\d+)% loss\)"
$rttRegex  = [regex]"Minimum = (\d+)ms, Maximum = (\d+)ms, Average = (\d+)ms"
$obj = [ordered]@{ ip=$Ip; sent=$null; received=$null; lost=$null; lossPct=$null; minMs=$null; maxMs=$null; avgMs=$null }
$lm = $lossRegex.Match($raw)
if ($lm.Success) { $obj.sent=[int]$lm.Groups[1].Value; $obj.received=[int]$lm.Groups[2].Value; $obj.lost=[int]$lm.Groups[3].Value; $obj.lossPct=[int]$lm.Groups[4].Value }
$rm = $rttRegex.Match($raw)
if ($rm.Success) { $obj.minMs=[int]$rm.Groups[1].Value; $obj.maxMs=[int]$rm.Groups[2].Value; $obj.avgMs=[int]$rm.Groups[3].Value }
$summaryPath = Join-Path $workdir "summary.json"
$obj | ConvertTo-Json | Set-Content $summaryPath -Encoding UTF8
$zipPath = Join-Path $workdir "results.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$workdir\\*" -DestinationPath $zipPath -Force
Write-Host ""
Write-Host "Done. Outputs in: $workdir" -ForegroundColor Green
Write-Host " - Raw:     $rawPath"
Write-Host " - Summary: $summaryPath"
Write-Host " - ZIP:     $zipPath"
try { Invoke-Item $workdir } catch {}
