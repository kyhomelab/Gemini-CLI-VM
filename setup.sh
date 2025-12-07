#!/bin/bash

# This script automates the setup of the Gemini CLI VM environment.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Phase 1: Manual Steps ---
# 1. Create a new VM in Proxmox.
# 2. Install Ubuntu Server LTS.
# 3. Configure a static IP address.
# 4. Create a non-root user and configure SSH access.

# --- Phase 2: Core Software Installation ---

echo "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

echo "Installing git..."
sudo apt-get install -y git

echo "Installing curl..."
sudo apt-get install -y curl

echo "Installing VS Code Server..."
curl -fsSL https://code-server.dev/install.sh | sh
sudo systemctl enable --now code-server@$USER

echo "Installing Cloudflared..."
# Download and install the cloudflared package
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
rm cloudflared.deb

echo "Installing Node.js and Gemini CLI..."
# Install nvm (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# Install Node.js version 18
nvm install 18
# Install Gemini CLI
npm install -g @google/gemini-cli

echo "Core software installation complete."

# --- Future Phases (Networking, Git Setup, etc.) will be added here ---

exit 0
