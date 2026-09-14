#!/usr/bin/env bash
# Update Lynis to the latest version from GitHub

echo "Checking for Lynis updates..."
UPDATE_INFO=$(sudo lynis update info 2>/dev/null)
echo "$UPDATE_INFO" | grep -E "Version|Status"

if echo "$UPDATE_INFO" | grep -q "Status.*Up-to-date"; then
    echo "Lynis is already up-to-date. No pull needed."
else
    echo "Update available — pulling latest from GitHub..."
    sudo git -C /usr/local/lynis pull
    echo "Done. New version: $(lynis --version)"
fi
