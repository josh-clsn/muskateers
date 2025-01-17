#!/bin/bash
#
# antnode-updater.sh
# This script updates antnode binaries for multiple systemd services
# located under /var/antctl/services/antnode*, using a private GitHub
# binary download (requires a Personal Access Token).
#

#############################
#        CONFIGURATION      #
#############################

# Directory containing all the antnode services
services_dir="/var/antctl/services"

# URL for the new antnode binary (private repo)
new_binary_url="https://github.com/josh-clsn/muskateers/releases/download/2/antnode"

# The personal access token for GitHub (ideally from an environment var, e.g. $GITHUB_TOKEN).
# DO NOT hardcode your actual token here in real-world scenarios.
github_token="$GITHUB_TOKEN"

# Temporary download location for the new binary
new_binary="$HOME/antnode"

# Log file for script output
log_file="$HOME/update_log.txt"

# Wait times (in seconds) depending on prior state
wait_if_was_running=10
wait_if_was_not_running=60

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

# Make sure we have a GitHub token
if [ -z "$github_token" ]; then
    log "Error: No GitHub token provided. Please set the GITHUB_TOKEN environment variable."
    exit 1
fi

# Download the new binary from a private repo with an Authorization header
log "Downloading the latest antnode binary from a private GitHub repo..."
if ! wget --header="Authorization: Bearer $github_token" \
          -q -O "$new_binary" "$new_binary_url"; then
    log "Error: Failed to download the antnode binary (check URL or token)."
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
    else
        was_running=false
        log "$service_name is NOT running. Will replace the binary and then start it."
    fi

    # Replace the binary
    log "Replacing binary for $service_name..."
    cp "$new_binary" "$service_path/antnode"
    chmod +x "$service_path/antnode"
    log "Binary replaced successfully for $service_name."

    # If it was running, restart it. If not, start it anyway.
    log "Starting $service_name..."
    if ! systemctl start "$service_name"; then
        log "Error: Failed to start $service_name via systemctl."
        # Decide how to handle this error—continue or exit
        # For now, just logging and continuing.
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

