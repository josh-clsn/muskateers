#!/bin/bash
#
# antnode-manager.sh
# This script will manage multiple antnode systemd services,
# checking system RAM usage before starting each one, but it will
# NOT replace or update the existing binary.

#############################
#        CONFIGURATION      #
#############################

# Directory containing all the antnode services
services_dir="/var/antctl/services"

# Log file for script output
log_file="$HOME/update_log.txt"

# Wait times (in seconds) depending on prior state
wait_if_was_running=10
wait_if_was_not_running=60

# Threshold for RAM usage (in %)
ram_threshold=85

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
#        MAIN SCRIPT        #
#############################

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or via sudo."
    exit 1
fi

echo "============================================="
echo " antNode Manager (No Binary Replacement) "
echo "============================================="
echo "1) Manage ALL nodes (even if they're running)."
echo "2) ONLY manage nodes that are NOT running."
read -rp "Enter your choice [1 or 2]: " update_choice

# Validate choice
if [[ "$update_choice" != "1" && "$update_choice" != "2" ]]; then
    echo "Invalid choice. Please run the script again."
    exit 1
fi

log "====================="
log "Starting antnode manager script."
log "User selected option $update_choice."
log "====================="

# Ensure services directory exists
if [ ! -d "$services_dir" ]; then
    log "Error: Services directory '$services_dir' does not exist."
    exit 1
fi

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
            # If user chose "ONLY manage nodes that are NOT running", skip this one
            log "$service_name is RUNNING. User selected to skip running nodes. Skipping..."
            continue
        fi

        # Otherwise, stop it before "managing" (i.e., verifying it can be restarted, etc.)
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

    # NO BINARY REPLACEMENT HERE — intentionally omitted

    # Before starting, check RAM usage
    check_ram

    # Start the service
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

log "===================================="
log "All relevant services have been managed."
log "Script completed successfully."
log "===================================="

exit 0

