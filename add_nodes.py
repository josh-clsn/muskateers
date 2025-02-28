import subprocess

# Set initial port numbers
node_port = 6801
metrics_port = 13001

# Define the base command with placeholders
base_command = (
    "sudo -S $HOME/.local/bin/antctl add --count 1 "
    "--rewards-address {address} --version 0.3.6 "
    "--node-port {node_port} --enable-metrics-server --metrics-port {metrics_port} evm-arbitrum-one"
)

# Hard-coded Ethereum address
address = "0xYourEthereumAddressHere"

# Open the log file to record executed commands
with open("executed_commands.log", "w") as log_file:
    # Substitute address and ports in the command
    command = base_command.format(
        address=address,
        node_port=node_port,
        metrics_port=metrics_port
    )
    
    # Execute the command
    print(f"Running command for address: {address}")
    subprocess.run(command, shell=True)
    
    # Write the executed command to the log file
    log_file.write(f"{command}\n")
    
    # Increment the ports for the next iteration
    node_port += 1
    metrics_port += 1

print("Command executed and saved to executed_commands.log")

