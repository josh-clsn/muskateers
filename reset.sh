#!/bin/bash

# Prompt for sudo password
read -sp "Enter sudo password: " sudopass
echo

# Prompt for delay
read -p "Do you want to add a delay before running the script? (yes/no): " add_delay

if [ "$add_delay" = "yes" ]; then
  delay=$((RANDOM % 1201)) # Random delay between 0 and 1200 seconds (20 minutes)
  echo "Waiting for $delay seconds..."
  sleep $delay
fi

# Stop and disable the antnode service
echo $sudopass | sudo -S killall antnode
if [ $? -eq 0 ]; then
  echo "Successfully killed antnode processes"
else
  echo "Failed to kill antnode processes or no processes found"
fi

echo $sudopass | sudo -S systemctl disable --now antnodeX
if [ $? -eq 0 ]; then
  echo "Successfully disabled antnodeX service"
else
  echo "Failed to disable antnodeX service"
fi

# Remove systemd unit files
echo $sudopass | sudo -S rm /etc/systemd/system/antnode*
if [ $? -eq 0 ]; then
  echo "Successfully removed antnode systemd files"
else
  echo "Failed to remove antnode systemd files or no files found"
fi

# Remove antctl directories
echo $sudopass | sudo -S rm -rf /var/antctl
if [ $? -eq 0 ]; then
  echo "Successfully removed /var/antctl"
else
  echo "Failed to remove /var/antctl or directory not found"
fi

echo $sudopass | sudo -S rm -rf /var/log/antnode
if [ $? -eq 0 ]; then
  echo "Successfully removed /var/log/antnode"
else
  echo "Failed to remove /var/log/antnode or directory not found"
fi

# Reload systemd daemon
echo $sudopass | sudo -S systemctl daemon-reload
if [ $? -eq 0 ]; then
  echo "Successfully reloaded systemd daemon"
else
  echo "Failed to reload systemd daemon"
fi
