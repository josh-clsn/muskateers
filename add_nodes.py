import csv
import subprocess

# Set initial port numbers
node_port = 6801
metrics_port = 13001

# Define the base command with placeholders
base_command = (
    "sudo -S $HOME/.local/bin/safenode-manager add --count 1 "
    "--rewards-address {address} --auto-restart --version 0.112.3 "
    "--node-port {node_port} --enable-metrics-server --metrics-port {metrics_port} evm-arbitrum-sepolia"
)

# Set your desired range
start_index = 0  # Start at the second address (0-based index)
end_index = 20   # End at the 30th address (exclusive)

# Open the log file to record executed commands
with open("executed_commands.log", "w") as log_file:
    # Read addresses from CSV
    with open("eth_addresses_all.csv", "r") as file:
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

