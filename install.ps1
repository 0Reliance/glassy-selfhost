<#
.SYNOPSIS
  Glassy Self-Host installer for Windows (Docker Desktop).

.DESCRIPTION
  Checks this machine, writes .env (keeping anything already there), starts
  Glassy and confirms it is running. Safe to run again: it never replaces a
  value you already set and never touches your data.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Check
  .\install.ps1 -Email you@example.com -TokenFile $HOME\glassy-token.txt -Yes

.NOTES
  Exit codes: 0 running and confirmed ; 10 Docker missing or not running ;
  11 port in use ; 12 a required value is missing ; 13 another container
  already uses the name "glassy" ; 20 Glassy did not start ; 21 started, but
  did not become healthy in time
#>
[CmdletBinding()]
param(
  [string]$Email = $env:GLASSY_MEMBER_EMAIL,
  [string]$Token = $env:GLASSY_SELFHOST_TOKEN,
  [string]$TokenFile,
  [string]$Cloud,
  [int]$Port = 0,
  [switch]$WithOllama,
  [switch]$Yes,
  [switch]$Check,
  [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

# Run a native command quietly and return its exit code. Windows PowerShell 5 turns anything
# a native command writes to its error stream into a terminating error when output is
# redirected under ErrorActionPreference = Stop, and Docker writes its progress there.
function Invoke-Quiet {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $args[0] $args[1..($args.Count - 1)] 2>&1 | Out-Null } catch { }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  return $code
}
function Invoke-Text {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { $out = & $args[0] $args[1..($args.Count - 1)] 2>$null } catch { $out = $null }
  $ErrorActionPreference = $old
  return $out
}
function Read-Lines($path) { return @([System.IO.File]::ReadAllLines((Resolve-Path $path), [System.Text.Encoding]::UTF8)) }

function Ok($m)   { Write-Host '  ok    ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Note($m) { Write-Host '  note  ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Step($m) { Write-Host ''; Write-Host $m -ForegroundColor White }
function Stop-Install($m, $hint, $code) {
  Write-Host ''
  Write-Host '  stopped  ' -ForegroundColor Yellow -NoNewline; Write-Host $m
  if ($hint) { Write-Host "           $hint" }
  exit $code
}

function Get-EnvValue($key) {
  if (-not (Test-Path .env)) { return '' }
  $line = Read-Lines .env | Where-Object { $_ -match "^$key=" } | Select-Object -Last 1
  if ($line) { return $line.Substring($key.Length + 1) } else { return '' }
}
function Set-EnvValue($key, $value) {
  $lines = Read-Lines .env
  $done = $false
  $out = foreach ($l in $lines) {
    if (-not $done -and $l -match "^$key=") { "$key=$value"; $done = $true } else { $l }
  }
  if (-not $done) { $out = @($out) + "$key=$value" }
  # LF line endings and no byte-order mark: the file is read inside a Linux container.
  [System.IO.File]::WriteAllText((Join-Path $PWD '.env'), (($out -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
function New-HexSecret {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
function Test-PortInUse($p) {
  try {
    $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $p)
    $l.Start(); $l.Stop(); return $false
  } catch { return $true }
}
function Get-Json($url) {
  try { return Invoke-RestMethod -Uri $url -TimeoutSec 5 } catch { return $null }
}
function Get-GlassyOwner {
  $o = Invoke-Text docker inspect glassy --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'
  if ($LASTEXITCODE -ne 0) { return $null }
  return $o
}
function Same-Folder($a, $b) {
  if (-not $a -or -not $b) { return $false }
  return ($a.TrimEnd('\','/') -ieq $b.TrimEnd('\','/'))
}

# -- 1. Check this machine ----------------------------------------------------
Step 'Checking this machine'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Stop-Install "Docker isn't installed." 'Install Docker Desktop, then run this again: https://docs.docker.com/get-docker/' 10
}
if ((Invoke-Quiet docker info) -ne 0) { Stop-Install "Docker is installed but isn't running." 'Start Docker Desktop, wait for it to finish starting, then run this again.' 10 }
if ((Invoke-Quiet docker compose version) -ne 0) { Stop-Install "This Docker doesn't have Compose v2." 'Update Docker Desktop.' 10 }
Ok 'Docker and Compose are ready'

if (-not ((Test-Path .env.example) -and (Test-Path docker-compose.yml))) {
  Stop-Install "This doesn't look like the Glassy Self-Host folder." 'Run install.ps1 from the folder you cloned (it holds docker-compose.yml and .env.example).' 12
}

$alreadyRunning = $false
$names = @(Invoke-Text docker ps -a --format '{{.Names}}')
if ($names -contains 'glassy') {
  $owner = Get-GlassyOwner
  $running = @(Invoke-Text docker ps --format '{{.Names}}') -contains 'glassy'
  if (Same-Folder $owner $PWD.Path) {
    if ($running) { $alreadyRunning = $true; Ok 'Glassy from this folder is already running' }
  } else {
    $state = if ($running) { 'is already running' } else { 'already exists (stopped)' }
    $where = if ($owner) { " ($owner)" } else { '' }
    Stop-Install "A container named `"glassy`" $state from somewhere else$where." 'That is another Glassy on this machine. Nothing was changed. Use that folder, or stop that one first if you mean to replace it.' 13
  }
}

if ($Port -eq 0) { $p = Get-EnvValue 'APP_PORT'; if ($p) { $Port = [int]$p } else { $Port = 3000 } }
if (-not $alreadyRunning) {
  if (Test-PortInUse $Port) { Stop-Install "Port $Port is already in use on this machine." 'Pick another one, for example: .\install.ps1 -Port 3005' 11 }
  Ok "Port $Port is free"
}

$drive = (Get-Item $PWD.Path).PSDrive
if ($drive -and $drive.Free -lt 4GB) { Note "Less than 4 GB of disk is free here. Glassy needs about 2 GB, plus room for your notes." } else { Ok 'Enough disk space' }

if ($Check) { Write-Host ''; Write-Host 'This machine is ready for Glassy. Nothing was changed.'; exit 0 }

# -- 2. Settings (.env) -------------------------------------------------------
Step 'Settings'

if (-not (Test-Path .env)) {
  $text = ([System.IO.File]::ReadAllText((Resolve-Path .env.example), [System.Text.Encoding]::UTF8)) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText((Join-Path $PWD '.env'), $text, (New-Object System.Text.UTF8Encoding($false)))
  Ok 'Made .env from .env.example'
} else { Ok 'Keeping your existing .env' }

if (-not $Email) { $Email = Get-EnvValue 'GLASSY_MEMBER_EMAIL' }
if ($TokenFile) {
  if (-not (Test-Path $TokenFile)) { Stop-Install "Can't read the token file $TokenFile." '' 12 }
  $Token = ([System.IO.File]::ReadAllText((Resolve-Path $TokenFile))).Trim()
}
if (-not $Token) { $Token = Get-EnvValue 'GLASSY_SELFHOST_TOKEN' }

switch -Regex ($Cloud) {
  '^$'      { $CloudUrl = Get-EnvValue 'GLASSY_VERIFY_CLOUD_URL'; if (-not $CloudUrl) { $CloudUrl = 'https://app.glassy.fyi' } }
  '^app$'   { $CloudUrl = 'https://app.glassy.fyi' }
  '^clear$' { $CloudUrl = 'https://clear.glassy.fyi' }
  '^http'   { $CloudUrl = $Cloud.TrimEnd('/') }
  default   { Stop-Install '-Cloud takes app, clear, or a full https:// address.' '' 12 }
}

$interactive = (-not $Yes) -and [Environment]::UserInteractive
if (-not $Email) {
  if ($interactive) { $Email = Read-Host '  Your Glassy account email (a free account is enough; sign up at https://glassy.fyi)' }
  if (-not $Email) { Stop-Install 'Glassy needs your account email.' 'Run again with -Email you@example.com' 12 }
}
if (-not $Token) {
  if ($interactive) {
    Write-Host ''
    Write-Host '  Your pairing token ties this Glassy to your account.'
    Write-Host "  Make one at $CloudUrl/#/settings?g=account&s=selfhost  (Settings > Account > Self-hosting > Generate token)"
    $secure = Read-Host '  Paste it here (it will not be shown)' -AsSecureString
    $Token = [System.Net.NetworkCredential]::new('', $secure).Password
  }
  if (-not $Token) { Stop-Install 'Glassy needs your pairing token.' "Make one at $CloudUrl/#/settings?g=account&s=selfhost, save it to a file, and run again with -TokenFile <path>" 12 }
}

Set-EnvValue 'GLASSY_MEMBER_EMAIL' $Email
Set-EnvValue 'GLASSY_SELFHOST_TOKEN' $Token
Set-EnvValue 'GLASSY_VERIFY_CLOUD_URL' $CloudUrl
Ok "Account: $Email  (at $($CloudUrl -replace '^https://',''))"

$made = $false
if (-not (Get-EnvValue 'JWT_SECRET')) { Set-EnvValue 'JWT_SECRET' (New-HexSecret); $made = $true }
if (-not (Get-EnvValue 'API_KEY_ENCRYPTION_KEY')) { Set-EnvValue 'API_KEY_ENCRYPTION_KEY' (New-HexSecret); $made = $true }
if ($made) { Ok "Made this machine's two secret keys (kept in .env; back that file up)" } else { Ok 'Keeping the secret keys already in .env' }

$Tag = Get-EnvValue 'GLASSY_TAG'
if (-not $Tag) { Stop-Install '.env has no GLASSY_TAG.' 'Copy the GLASSY_TAG line from .env.example into .env.' 12 }
if ($Tag -in @('latest','main')) { Stop-Install "GLASSY_TAG is `"$Tag`", which is the build for Glassy's own cloud and hides the self-host features." 'Set GLASSY_TAG in .env to the version in .env.example.' 12 }
Ok "Version: $Tag"

if ($Port -ne 3000 -or (Get-EnvValue 'APP_PORT')) {
  Set-EnvValue 'APP_PORT' $Port
  $u = Get-EnvValue 'APP_URL';      if (-not $u -or $u -like 'http://localhost:*') { Set-EnvValue 'APP_URL' "http://localhost:$Port" }
  $c = Get-EnvValue 'CORS_ORIGINS'; if (-not $c -or ($c -like 'http://localhost:*' -and $c -notlike '*,*')) { Set-EnvValue 'CORS_ORIGINS' "http://localhost:$Port" }
  if ($Port -ne 3000) { Ok "Glassy will answer on port $Port" }
}

if ($NoStart) { Write-Host ''; Write-Host '.env is ready. Start Glassy when you like with:  docker compose up -d'; exit 0 }

# -- 3. Start -----------------------------------------------------------------
Step 'Starting Glassy'

# If the bundled Ollama was started from this folder before, keep it in the picture.
if (-not $WithOllama) {
  $ollamaOwner = Invoke-Text docker inspect glassy-ollama --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'
  if (Same-Folder $ollamaOwner $PWD.Path) { $WithOllama = $true }
}
$compose = @('compose','-f','docker-compose.yml')
if ($WithOllama) { $compose += @('-f','docker-compose.ollama.yml') }

Write-Host "  Getting Glassy $Tag (about 2 GB the first time)..." -ForegroundColor DarkGray
$pullArgs = $compose + @('pull','--quiet')
if ((Invoke-Quiet docker @pullArgs) -ne 0) { Stop-Install "Couldn't download Glassy $Tag." "Check this machine's internet connection, then run this again. Nothing else was changed." 20 }
$upArgs = $compose + @('up','-d')
if ((Invoke-Quiet docker @upArgs) -ne 0) { Stop-Install "Docker couldn't start Glassy." 'See why with:  docker compose logs --tail 40 glassy' 20 }

$Base = "http://localhost:$Port"
$health = $null
for ($i = 0; $i -lt 60; $i++) {
  $health = Get-Json "$Base/api/health"
  if ($health -and $health.status -eq 'ok') { break }
  Start-Sleep -Seconds 3
}
if (-not ($health -and $health.status -eq 'ok')) { Stop-Install "Glassy started but isn't answering yet." 'Give it a minute, then check:  docker compose logs --tail 40 glassy' 21 }

$running = "v$($health.version)"
if ($running -eq $Tag) { Ok "Glassy $running is running at $Base" } else { Note "Glassy is running at $Base as $running, though .env asks for $Tag" }

$instance = Get-Json "$Base/api/instance"
if (-not $instance -or $instance.instanceId -ne 'self_hosted') { Note "This build doesn't report itself as a self-host. Check GLASSY_TAG in .env against .env.example." }
if ($instance -and $instance.membershipState -eq 'verified') { Ok 'Your account is confirmed' }
else {
  Note "Glassy couldn't confirm your account just now. Everything on this machine works."
  Note 'It checks again at the next start. If it stays this way, check the email and token in .env.'
}

# -- 4. What's next -----------------------------------------------------------
Step 'Glassy is ready'
if ((Invoke-Quiet docker exec glassy test -f /app/data/.initial_admin_password) -eq 0) {
  Write-Host @"

  1. Read your first sign-in details (email on line one, password on line two):
       docker exec glassy cat /app/data/.initial_admin_password
  2. Open $Base and sign in. Glassy asks you to choose your own password
     straight away; the first one stops working after that.
"@
} else {
  Write-Host ''
  Write-Host "  Open $Base and sign in with your own password."
}
Write-Host @"

  Then:
    - Choose where AI runs, connect an assistant, link Obsidian:  docs\configure.md
    - Setting this up with an AI agent? Point it at:              AGENTS.md
    - Check on Glassy any time (in Git Bash):                     ./doctor.sh

  Back up .env. It holds the two keys that unlock this Glassy's data.
"@
