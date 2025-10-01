
    Param(
      [string]$PagesUrl = "$(Read-Host 'Enter your GitHub Pages base URL (e.g., https://<you>.github.io/net-ping-test)')"
    )

    if (-not $PagesUrl) { Write-Error "PagesUrl is required"; exit 1 }

    # Normalize: remove trailing slash
    if ($PagesUrl.EndsWith("/")) { $PagesUrl = $PagesUrl.TrimEnd("/") }

    $ErrorActionPreference = "Stop"

    # Build command that PowerShell will run when llsdiag:// is invoked.
    # It parses ?ip= and ?dur= from the custom URL, downloads Runner.ps1 from GitHub Pages, and executes it.
    $command = @"
    $u = '%1';
    if ($u -match 'ip=([^&]+)') { $ip = $matches[1] } else { $ip = '216.20.237.2' }
    if ($u -match 'dur=([^&]+)') { $dur = [int]$matches[1] } else { $dur = 900 }
    \$src = Invoke-WebRequest -UseBasicParsing '$PagesUrl/Runner.ps1';
    Invoke-Expression \$src.Content;
    Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile','-ExecutionPolicy','Bypass','-Command',('Start-LLSPing -Ip ''{0}'' -DurationSeconds {1}' -f $ip,$dur)) -Verb RunAs
"@

    # The Runner.ps1 defines Start-LLSPing. Keep the function name matching below.
    # We embed a small wrapper at the top of Runner.ps1 content to define Start-LLSPing if not present.
    # Actually Runner.ps1 already defines it as a script with Param, so we will generate a small function here to call it.

    # Register llsdiag:// protocol for current user
    $baseKey = "HKCU:\\Software\\Classes\\llsdiag"
    New-Item -Path $baseKey -Force | Out-Null
    New-ItemProperty -Path $baseKey -Name "(Default)" -Value "URL:LLS Diag Protocol" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $baseKey -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null

    $cmdKey = Join-Path $baseKey "shell\\open\\command"
    New-Item -Path $cmdKey -Force | Out-Null

    $psPath = "$env:WINDIR\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    $fullCmd = "`"$psPath`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -Command `"$command`""

    New-ItemProperty -Path $cmdKey -Name "(Default)" -Value $fullCmd -PropertyType String -Force | Out-Null

    Write-Host "Registered llsdiag:// protocol for current user." -ForegroundColor Green
    Write-Host "Test by clicking: llsdiag://run?ip=216.20.237.2&dur=900"
