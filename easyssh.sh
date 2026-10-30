#!/usr/bin/env bash
# EasySSH: create (or reuse) a local SSH key and install its public half on a server.
# The password is entered by OpenSSH at its normal interactive prompt and is never stored.

set -u

fail() {
    printf 'EasySSH: %s\n' "$1" >&2
    exit 1
}

command -v ssh >/dev/null 2>&1 || fail 'OpenSSH client (ssh) is required.'
command -v ssh-keygen >/dev/null 2>&1 || fail 'OpenSSH key tools (ssh-keygen) are required.'

printf 'Server hostname or IP: '
IFS= read -r host || fail 'Could not read hostname.'
printf 'SSH username: '
IFS= read -r username || fail 'Could not read username.'

[[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9.:-]*$ ]] || fail 'Use letters, numbers, dots, colons, and hyphens in the hostname or IP.'
[[ "$username" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'Use letters, numbers, dots, underscores, and hyphens in the username.'

ssh_dir="$HOME/.ssh"
private_key="$ssh_dir/id_ed25519"
public_key="$private_key.pub"
mkdir -p "$ssh_dir" || fail "Could not create $ssh_dir."
chmod 700 "$ssh_dir" || fail "Could not secure $ssh_dir."

if [[ ! -e "$private_key" ]]; then
    printf 'Creating an Ed25519 key at %s\n' "$private_key"
    ssh-keygen -t ed25519 -f "$private_key" -N '' -C "$username@$host" || fail 'Key generation failed.'
elif [[ ! -f "$public_key" ]]; then
    fail "A private key exists at $private_key but its .pub file is missing. Restore the matching public key and try again."
else
    printf 'Using your existing default Ed25519 key. It will not be overwritten.\n'
fi

IFS= read -r key_line < "$public_key" || fail 'Could not read the public key.'
read -r key_type key_data _ <<< "$key_line"
[[ "$key_type" == 'ssh-ed25519' && "$key_data" =~ ^[A-Za-z0-9+/]+={0,3}$ ]] || fail 'The public key file does not look like a valid Ed25519 key.'
# Drop the optional comment so its contents cannot alter the remote shell command.
key_line="$key_type $key_data"
destination="$username@$host"
remote_command="umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && (grep -qxF '$key_line' ~/.ssh/authorized_keys || printf '%s\\n' '$key_line' >> ~/.ssh/authorized_keys) && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

printf '\nInstalling the public key on %s\n' "$destination"
printf 'Verify the server host-key fingerprint with its administrator before accepting it.\n'
printf 'Enter the server password at the OpenSSH prompt; EasySSH does not capture or save it.\n'
ssh "$destination" "$remote_command" || fail 'Server setup failed. Check the hostname, username, password, host fingerprint, and server SSH access.'

printf '\nKey installed. Try: ssh %s\n' "$destination"
printf 'Private key: %s\n' "$private_key"
