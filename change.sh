#!/bin/bash

# Set variables
services_dir="/var/antctl/services"
new_binary_url="https://github.com/josh-clsn/muskateers/releases/download/2/antnode"
new_binary="$HOME/antnode"
log_file="$HOME/update_log.txt"

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
log "Downloading the latest antnode binary..."
if ! wget -q -O "$new_binary" "$new_binary_url"; then
    log "Error: Failed to download the antnode binary."
    exit 1
fi

# Make the downloaded binary executable
log "Setting execute permissions on the antnode binary..."
chmod +x "$new_binary"

# Initialize counter for batch processing
counter=0
batch_size=10  # Adjust as needed

# Loop through each antnode service directory
for service_path in "$services_dir"/antnode*; do
    # Ensure we're only processing directories
    if [ ! -d "$service_path" ]; then
        log "Skipping non-directory item: $service_path"
        continue
    fi

    # Extract the service name (e.g., antnode13)
    service_name=$(basename "$service_path")

    log "Processing $service_name..."

    # Always replace the binary, regardless of its current state
    log "Replacing binary for $service_name..."
    cp "$new_binary" "$service_path/antnode"

    # Set execute permissions
    chmod +x "$service_path/antnode"

    log "Update successful for $service_name."

    # Batch processing control
    ((counter++))
    if (( counter % batch_size == 0 )); then
        log "Pausing briefly to prevent resource exhaustion..."
        sleep 1  # Adjust sleep duration as needed
    fi
done

# Clean up the downloaded binary
log "Cleaning up the downloaded binary..."
rm "$new_binary"

log "All services have had their binaries replaced successfully."

exit 0
