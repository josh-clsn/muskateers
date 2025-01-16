#!/bin/bash

# Set variables
services_dir="/var/antctl/services"
new_binary_url="https://github.com/josh-clsn/muskateers/releases/download/1/antnode"
new_binary="$HOME/antnode"
log_file="$HOME/update_log.txt"
sleep_interval=60   # Wait time (in seconds) between updating each node

# Simple logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script as root or with sudo."
    exit 1
fi

log "Starting antnode binary replacement script."

# Check if services directory exists
if [ ! -d "$services_dir" ]; then
    log "Error: Services directory '$services_dir' does not exist."
    exit 1
fi

# Download the latest antnode binary
log "Downloading the latest antnode binary from $new_binary_url..."
if ! wget -q -O "$new_binary" "$new_binary_url"; then
    log "Error: Failed to download the antnode binary."
    exit 1
fi

# Make the downloaded binary executable
log "Setting execute permissions on the antnode binary..."
chmod +x "$new_binary"

# Loop through each antnode service directory
for service_path in "$services_dir"/antnode*; do
    # Ensure we're only processing directories
    if [ ! -d "$service_path" ]; then
        log "Skipping non-directory item: $service_path"
        continue
    fi

    # Extract the service name (e.g., antnode1, antnode2, antnode3...)
    service_name=$(basename "$service_path")

    log "Processing $service_name..."

    # Check if the service is currently running
    if systemctl is-active --quiet "$service_name"; then
        was_running=true
        log "$service_name is currently running. Stopping it..."
        if ! systemctl stop "$service_name"; then
            log "Warning: Failed to stop $service_name via systemctl."
        fi
        
        # Ensure the process is indeed stopped
        pkill -f "$service_name"
    else
        was_running=false
        log "$service_name is not running. Will only replace the binary."
    fi

    # Replace the binary
    log "Replacing binary for $service_name..."
    cp "$new_binary" "$service_path/antnode"
    chmod +x "$service_path/antnode"
    log "Binary replaced successfully for $service_name."

    # If the service was running, start it again
    if [ "$was_running" = true ]; then
        log "Starting the service: $service_name"
        if ! systemctl start "$service_name"; then
            log "Error: Failed to start $service_name via systemctl."
            # Decide whether you want to continue or exit here
            continue
        fi
    fi

    # Wait 60 seconds before processing the next node
    log "Waiting $sleep_interval seconds before processing the next node..."
    sleep "$sleep_interval"
done

# Clean up the downloaded binary
log "Cleaning up the downloaded binary..."
rm -f "$new_binary"

log "All relevant services have been updated."
exit 0
