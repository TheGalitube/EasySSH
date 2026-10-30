# EasySSH

EasySSH prepares key-based SSH login for a server. It includes a PowerShell script and `.bat` launcher for Windows, plus a Bash script for Linux and macOS.

It asks for a hostname or IP and SSH username, creates an Ed25519 key in your normal OpenSSH key folder (or reuses the existing default key), installs the public key on the server, and adds a host entry to your SSH config. The server password is entered only in OpenSSH's own interactive prompt; EasySSH never reads or saves it. After setup, connect with either command:

```powershell
ssh hostname
# or
ssh username@hostname
```

The host entry is also available to tools that read `~/.ssh/config`, such as VS Code Remote SSH. If an entry for that host already exists, EasySSH leaves it unchanged.

## Requirements

- Windows 10 or 11 with the **OpenSSH Client** optional feature, or Linux/macOS with `ssh` and `ssh-keygen` installed
- A server account that can log in with a password and write to its `~/.ssh` directory

## Run

### Windows

Double-click `EasySSH.bat`, or run from PowerShell in this folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\EasySSH.ps1
```

### Linux and macOS

Run from a terminal in this folder:

```sh
chmod +x ./easyssh.sh
./easyssh.sh
```

When OpenSSH asks whether to trust a server's host key, verify the displayed fingerprint with the server administrator before accepting it. This protects the first connection from connecting to an impostor server.

EasySSH does not overwrite an existing `~/.ssh/id_ed25519` key. If one exists, it installs that key's public half. Keep the private key private; only the `.pub` file is sent to the server.
