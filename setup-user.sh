#!/usr/bin/env bash
set -e
if [[ -z "$TARGET" ]]; then
    echo "Set TARGET environment variable to match SSH host to be run"
    exit 1
fi
if [[ -z "$NEW_USER" ]]; then
    echo "Set NEW_USER envrionment variable with created user's name"
    exit 1
fi
if [[ -z "$SSH_KEY" ]]; then
    echo "Set SSH_KEY envrionment variable with SSH pub key to be used for login"
    exit 1
fi

ssh "root@${TARGET}" <<EOF
set -e
if ! id -u "$NEW_USER" &>/dev/null; then
    echo "Creating user $NEW_USER"
    useradd --create-home --shell "\$(command -v bash)" "$NEW_USER"
    echo "User $NEW_USER" created
else
    echo "No need to create a user (exists)"
fi

authorized_keys="/home/$NEW_USER/.ssh/authorized_keys"
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" \$(dirname "\$authorized_keys")
test -f "\$authorized_keys" || touch "\$authorized_keys"
chmod 600 "\$authorized_keys"
chown "$NEW_USER:$NEW_USER" "\$authorized_keys"

if ! grep -q "$SSH_KEY" "\$authorized_keys"; then
    echo "Authorizing SSH key $SSH_KEY"
    echo "$SSH_KEY" >>"\$authorized_keys"
else
    echo "SSH key already saved"
fi
EOF

ssh "${NEW_USER}@${TARGET}" <<'EOF'
set -e
cat <<'BASHRC' >/tmp/bashrc
export PATH=$HOME/.local/bin:$HOME/go/bin:$PATH
df -h | grep '/$' | awk '{print "Available "$4" (used "$5") of "$2}'
echo "Podman containers:" && podman ps --format 'table {{.Names}}  {{.Status}}  {{.ID}}'
BASHRC

while read -r line; do
    if grep -q "^$line\$" ~/.bashrc; then
        echo "Skipping (already added) line:[$line]"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to ~/.bashrc line:[$line]"
    fi
done </tmp/bashrc
rm /tmp/bashrc
EOF
