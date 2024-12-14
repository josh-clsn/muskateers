import csv
import subprocess

# Function to determine the last used ports
def get_last_used_ports(log_file_path):
    try:
        with open(log_file_path, "r") as log_file:
            lines = log_file.readlines()
            if lines:
                # Parse the last line for node_port and metrics_port
                last_line = lines[-1]
                parts = last_line.split()
                node_port = int([p.split("=")[1] for p in parts if "--node-port" in p][0])
                metrics_port = int([p.split("=")[1] for p in parts if "--metrics-port" in p][0])
                return node_port + 1, metrics_port + 1
    except FileNotFoundError:
        print("Log file not found. Using default ports.")
    return 6801, 13001  # Defaults

# Get starting ports
log_file_path = "executed_commands.log"
node_port, metrics_port = get_last_used_ports(log_file_path)

# Define the base command with placeholders
base_command = (
    "sudo -S $HOME/.local/bin/antctl add --count 1 "
    "--rewards-address {address} --auto-restart --version 0.112.3 "
    "--node-port {node_port} --enable-metrics-server --metrics-port {metrics_port} evm-arbitrum-sepolia"
)

# Set your desired range
start_index = 261  # Start after previously used indices
end_index = 301    # Adjust as needed for the new range

# Open the log file to record executed commands
with open(log_file_path, "a") as log_file:  # Append mode
    # Read addresses from CSV
    with open("eth_addresses.csv", "r") as file:
        reader = list(csv.DictReader(file))  # Convert to a list for easier slicing
        
        # Slice the list of addresses based on the specified range
        for i, row in enumerate(reader[start_index:end_index], start=start_index):
            # Substitute address and ports in the command
            command = base_command.format(
                address=row["Address"],
                node_port=node_port,
                metrics_port=metrics_port
            )
            
            # Execute the command
            print(f"Running command for address {i}: {row['Address']}")
            subprocess.run(command, shell=True)
            
            # Write the executed command to the log file
            log_file.write(f"{command}\n")
            
            # Increment the ports for the next iteration
            node_port += 1
            metrics_port += 1

print("Selected range of commands executed and saved to executed_commands.log")
