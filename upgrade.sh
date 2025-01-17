#!/bin/bash
#
# antnode-updater.sh
# This script updates antnode binaries for multiple systemd services
# located under /var/antctl/services/antnode*.
#

#############################
#        CONFIGURATION      #
#############################

# Directory containing all the antnode services
services_dir="/var/antctl/services"

# URL for the new antnode binary
new_binary_url="https://github.com/josh-clsn/muskateers/releases/download/2/antnode"

# Temporary download location for the new binary
new_binary="$HOME/antnode"

# Log file for script output
log_file="$HOME/update_log.txt"

# How long (in seconds) to wait between updating each node
sleep_interval=10

#############################
#       LOGGING SETUP       #
#############################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

#############################
#        MAIN SCRIPT        #
#############################

# Must run as root
if [ "$EUID" -ne 0 ]; then
    log "Error: Please run this script as root or via sudo."
    exit 1
fi

log "====================="
log "Starting antnode update script."
log "====================="

# Ensure services directory exists
if [ ! -d "$services_dir" ]; then
    log "Error: Services directory '$services_dir' does not exist."
    exit 1
fi

# Download the new binary
log "Downloading the latest antnode binary from $new_binary_url..."
if ! wget -q -O "$new_binary" "$new_binary_url"; then
    log "Error: Failed to download the antnode binary."
    exit 1
fi

# Make the downloaded binary executable
log "Setting execute permissions on the downloaded binary..."
chmod +x "$new_binary"

# Iterate through each antnode service directory
for service_path in "$services_dir"/antnode*; do
    # Skip if it's not a directory
    if [ ! -d "$service_path" ]; then
        log "Skipping non-directory item: $service_path"
        continue
    fi

    # Extract the systemd service name (e.g., antnode1, antnode2, etc.)
    service_name=$(basename "$service_path")

    log "---------------------------------------"
    log "Processing service: $service_name"
    log "---------------------------------------"

    # Check if service is running
    if systemctl is-active --quiet "$service_name"; then
        was_running=true
        log "$service_name is running. Attempting to stop it..."
        if ! systemctl stop "$service_name"; then
            log "Warning: Failed to stop $service_name via systemctl."
            # Decide how you want to handle this error—continue or exit
            # For now, we just log and continue.
        fi
        
        # Optionally verify it's really stopped. For safety, we can wait a few seconds:
        for i in {1..5}; do
            if ! systemctl is-active --quiet "$service_name"; then
                log "$service_name successfully stopped."
                break
            fi
            log "Waiting for $service_name to fully stop..."
            sleep 1
        done
    else
        was_running=false
        log "$service_name is not running. Proceeding with binary replacement."
    fi

    # Replace the binary
    log "Replacing binary for $service_name..."
    cp "$new_binary" "$service_path/antnode"
    chmod +x "$service_path/antnode"
    log "Binary replaced successfully for $service_name."

    # If it was running before, start it again
    if [ "$was_running" = true ]; then
        log "Starting $service_name..."
        if ! systemctl start "$service_name"; then
            log "Error: Failed to start $service_name via systemctl."
            # Decide how you want to handle this error—continue or exit
            # For now, we just log and continue.
        else
            # Optionally check status again
            for i in {1..5}; do
                if systemctl is-active --quiet "$service_name"; then
                    log "$service_name is running again."
                    break
                fi
                log "Waiting for $service_name to show as active..."
                sleep 1
            done
        fi
    fi

    # Wait before processing the next node
    log "Waiting $sleep_interval seconds before updating the next service..."
    sleep "$sleep_interval"
done

# Remove the temporarily downloaded binary
log "Cleaning up the downloaded binary from $new_binary..."
rm -f "$new_binary"

log "===================================="
log "All relevant services have been updated."
log "Script completed successfully."
log "===================================="

exit 0
