#!/bin/bash
#
# antnode-updater.sh
# This script updates antnode binaries for multiple systemd services
# located under /var/antctl/services/antnode*.
#
# It only monitors system-wide RAM usage and disk usage right before starting a node.
# If RAM usage hits >= 85% or disk usage reaches >= 80%, the script immediately terminates.
#

#############################
#        CONFIGURATION      #
#############################

# Directory containing all the antnode services
services_dir="/var/antctl/services"

# URL for the new antnode binary
new_binary_url="https://github.com/josh-clsn/muskateers/releases/download/1/antnode"

# Temporary download location for the new binary
new_binary="$HOME/antnode"

# Log file for script output
log_file="$HOME/update_log.txt"

# Wait times (in seconds) depending on prior state
wait_if_was_running=10
wait_if_was_not_running=75

# Threshold for RAM usage (in %)
ram_threshold=85

# Threshold for Disk usage (in %)
disk_threshold=80

#############################
#       LOGGING SETUP       #
#############################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

#############################
#     FUNCTION: CHECK RAM   #
#############################
check_ram() {
    local used_percentage
    used_percentage=$(free | awk '/^Mem:/ { printf("%.0f", $3/$2 * 100) }')

    log "Current system memory usage: ${used_percentage}%"

    if (( used_percentage >= ram_threshold )); then
        log "Memory usage is at ${used_percentage}% (threshold ${ram_threshold}%). Terminating script."
        exit 1
    fi
}

#############################
#   FUNCTION: CHECK DISK    #
#############################
check_disk() {
    # Using the root filesystem (/) for disk space check. Adjust if needed.
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {gsub("%", ""); print $5}')
    log "Current disk usage: ${disk_usage}%"

    if (( disk_usage >= disk_threshold )); then
        log "Disk usage is at ${disk_usage}% (threshold ${disk_threshold}%). Terminating script."
        exit 1
    fi
}

#############################
#        MAIN SCRIPT        #
#############################

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or via sudo."
    exit 1
fi

echo "============================================="
echo " antNode Updater with On-Start RAM & Disk Check "
echo "============================================="
echo "1) Update ALL nodes (even if they're running)."
echo "2) ONLY update nodes that are NOT running."
read -rp "Enter your choice [1 or 2]: " update_choice

# Validate choice
if [[ "$update_choice" != "1" && "$update_choice" != "2" ]]; then
    echo "Invalid choice. Please run the script again."
    exit 1
fi

log "====================="
log "Starting antnode update script."
log "User selected option $update_choice."
log "====================="

# Ensure services directory exists
if [ ! -d "$services_dir" ]; then
    log "Error: Services directory '$services_dir' does not exist."
    exit 1
fi

# Download the new binary
log "Downloading the latest antnode binary from $new_binary_url..."
if ! wget -q -O "$new_binary" "$new_binary_url"; then
    log "Error: Failed to download the antnode binary. Check URL or connectivity."
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
        # The service is RUNNING
        if [ "$update_choice" = "2" ]; then
            # If user chose "ONLY update nodes that are NOT running", skip this one
            log "$service_name is RUNNING. User selected to skip running nodes. Skipping..."
            continue
        fi

        # Otherwise, stop and update
        log "$service_name is running. Stopping it..."
        if ! systemctl stop "$service_name"; then
            log "Warning: Failed to stop $service_name via systemctl."
            # Decide how to handle this error—continue or exit
            # For now, just logging and continuing.
        fi

        # Optionally verify it's actually stopped
        for i in {1..5}; do
            if ! systemctl is-active --quiet "$service_name"; then
                log "$service_name successfully stopped."
                break
            fi
            log "Waiting for $service_name to fully stop..."
            sleep 1
        done

        was_running=true
    else
        # The service is NOT RUNNING
        was_running=false
        log "$service_name is NOT running."
    fi

    # Replace the binary
    log "Replacing binary for $service_name..."
    cp "$new_binary" "$service_path/antnode"
    chmod +x "$service_path/antnode"
    log "Binary replaced successfully for $service_name."

    # Before starting, check RAM and Disk usage
    check_ram
    check_disk

    # Start the service if we updated it
    log "Starting $service_name..."
    if ! systemctl start "$service_name"; then
        log "Error: Failed to start $service_name via systemctl."
        # Decide how to handle this error—continue or exit
        # For now, just logging and continuing.
    else
        # Optionally check status again
        for i in {1..5}; do
            if systemctl is-active --quiet "$service_name"; then
                log "$service_name is running."
                break
            fi
            log "Waiting for $service_name to show as active..."
            sleep 1
        done
    fi

    # Wait before processing the next service, depending on prior state
    if [ "$was_running" = true ]; then
        log "Service $service_name was running before, waiting $wait_if_was_running seconds..."
        sleep "$wait_if_was_running"
    else
        log "Service $service_name was NOT running before, waiting $wait_if_was_not_running seconds..."
        sleep "$wait_if_was_not_running"
    fi

done

# Remove the temporarily downloaded binary
log "Cleaning up the downloaded binary from $new_binary..."
rm -f "$new_binary"

log "===================================="
log "All relevant services have been updated."
log "Script completed successfully."
log "===================================="

exit 0
