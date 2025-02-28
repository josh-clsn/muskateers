import subprocess

# Set initial port numbers
node_port = 6801
metrics_port = 13001

# Define the base command with placeholders
base_command = (
    "sudo -S $HOME/.local/bin/antctl add --count 1 "
    "--rewards-address {address} --version 0.3.7 "
    "--node-port {node_port} --enable-metrics-server --metrics-port {metrics_port} evm-arbitrum-one"
)

# Hard-coded Ethereum address
address = "0x419B378a3A7F8D05f1B4A7601B27F602A2ebb70a"

# Substitute address and ports in the command
command = base_command.format(
    address=address,
    node_port=node_port,
    metrics_port=metrics_port
)

# Execute the command and log it
with open("executed_commands.log", "w") as log_file:
    print(f"Running command for address: {address}")
    subprocess.run(command, shell=True)
    log_file.write(f"{command}\n")

print("Command executed and saved to executed_commands.log")


