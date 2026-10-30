# EasySSH: create (or reuse) a local SSH key and install its public half on a server.
# Passwords are entered by OpenSSH at its normal interactive prompt and are never stored.

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Stop-WithMessage([string]$Message) {
    Write-Host "`n$Message" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue) -or -not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Stop-WithMessage 'OpenSSH was not found. Install the Windows OpenSSH Client feature, then run EasySSH again.'
}

$hostName = (Read-Host 'Server hostname or IP').Trim()
$userName = (Read-Host 'SSH username').Trim()
if ($hostName -notmatch '^[A-Za-z0-9][A-Za-z0-9.:-]*$') { Stop-WithMessage 'Enter a hostname or IP using letters, numbers, dots, colons, or hyphens.' }
if ($userName -notmatch '^[A-Za-z0-9._-]+$') { Stop-WithMessage 'Enter a username using letters, numbers, dots, underscores, or hyphens.' }

$sshDir = Join-Path $env:USERPROFILE '.ssh'
$privateKey = Join-Path $sshDir 'id_ed25519'
$publicKey = "$privateKey.pub"
New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $privateKey)) {
    Write-Info "Creating an Ed25519 key at $privateKey"
    # Windows PowerShell can drop a bare empty native-command argument. The
    # embedded quotes make the Windows argument parser pass an actual empty
    # value to ssh-keygen for -N (no key passphrase).
    & ssh-keygen -t ed25519 -f $privateKey -N '""' -C "$userName@$hostName"
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Key generation failed.' }
} elseif (-not (Test-Path -LiteralPath $publicKey)) {
    Stop-WithMessage "A private key exists at $privateKey but its .pub file is missing. Move or restore the matching public key, then try again."
} else {
    Write-Info 'Using your existing default Ed25519 key. It will not be overwritten.'
}

$keyText = (Get-Content -LiteralPath $publicKey -Raw).Trim()
if ($keyText -notmatch '^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( .*)?$') { Stop-WithMessage 'The public key file does not look like a valid Ed25519 key.' }
# Send only the key type and key data. Dropping the optional comment keeps shell metacharacters
# from a pre-existing public-key comment out of the remote command.
$keyParts = $keyText -split '\s+'
$keyText = "$($keyParts[0]) $($keyParts[1])"
$destination = "$userName@$hostName"
$quotedKey = "'$keyText'"
$remoteCommand = "umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && (grep -qxF $quotedKey ~/.ssh/authorized_keys || printf '%s\n' $quotedKey >> ~/.ssh/authorized_keys) && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

Write-Host ''
Write-Info "Installing the public key on $destination"
Write-Host 'OpenSSH may ask you to verify the server host key. Confirm its fingerprint with your server administrator before accepting.' -ForegroundColor Yellow
Write-Host 'Then enter the server password at the OpenSSH prompt. EasySSH does not capture or save it.'
& ssh $destination $remoteCommand
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'The server setup did not complete. Check the hostname, username, password, host fingerprint, and server SSH access, then run EasySSH again.' }

$sshConfig = Join-Path $sshDir 'config'
$escapedHost = [regex]::Escape($hostName)
$hasHostEntry = $false
if (Test-Path -LiteralPath $sshConfig) {
    $hasHostEntry = [bool](Get-Content -LiteralPath $sshConfig | Where-Object { $_ -match "^\s*Host\s+$escapedHost(?:\s|$)" } | Select-Object -First 1)
}
if (-not $hasHostEntry) {
    $configKeyPath = $privateKey.Replace('\', '/')
    $configBlock = "Host $hostName`r`n    HostName $hostName`r`n    User $userName`r`n    IdentityFile `"$configKeyPath`"`r`n    IdentitiesOnly yes"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    if (Test-Path -LiteralPath $sshConfig) {
        [System.IO.File]::AppendAllText($sshConfig, "`r`n$configBlock", $utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText($sshConfig, $configBlock, $utf8NoBom)
    }
    Write-Info "Added $hostName to $sshConfig"
} else {
    Write-Info "An SSH config entry for $hostName already exists; leaving it unchanged."
}

Write-Host "`nKey installed. Try: ssh $hostName (or ssh $destination)" -ForegroundColor Green
Write-Host "Private key: $privateKey"
Read-Host 'Press Enter to close'
