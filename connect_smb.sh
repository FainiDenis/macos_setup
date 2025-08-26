#!/bin/zsh

# Prompt for input
read -r "SERVER?Enter SMB server address (e.g. 192.168.1.123): "
read -r "USERNAME?Enter SMB username: "
echo -n "Enter SMB password: "
read -s PASSWORD
echo
read -r "SHARE?Enter shared folder name (e.g. media): "

# Input validation
if [[ -z "$SERVER" || -z "$USERNAME" || -z "$PASSWORD" || -z "$SHARE" ]]; then
    echo "❌ Error: All fields are required."
    exit 1
fi

# Build SMB URL
SMB_URL="smb://$USERNAME:$PASSWORD@$SERVER/$SHARE"

# Test connection with ping
ping -c 1 "$SERVER" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ Error: Cannot reach server at $SERVER."
    exit 1
fi

# Attempt to open SMB share
echo "🔌 Connecting to smb://$USERNAME@$SERVER/$SHARE..."
open "$SMB_URL"

# Wait a moment and check if the volume was mounted
sleep 3
MOUNT_POINT="/Volumes/$SHARE"
if mount | grep -q "$MOUNT_POINT"; then
    echo "✅ Successfully mounted $SHARE at $MOUNT_POINT"
else
    echo "⚠️ Could not verify mount. Check Finder or try again."
fi
