#!/bin/bash

#===============================================================================
# Gemini CLI VM Setup Script
#===============================================================================
#
# DESCRIPTION:
#   This script automates the setup of a Gemini CLI development environment
#   on Ubuntu Server LTS. It installs and configures all necessary software
#   for a remotely accessible development environment.
#
# PREREQUISITES (Manual Steps Before Running This Script):
#   1. Create a new VM in Proxmox with recommended specs:
#      - 2 vCPUs, 4 GB RAM, 50 GB storage
#   2. Install Ubuntu Server 22.04 LTS (minimal installation)
#   3. Configure a static IP address during installation
#   4. Create a non-root user (e.g., kyhomelab) during installation
#   5. Install OpenSSH server during installation
#   6. SSH into the VM and copy this script
#
# USAGE:
#   chmod +x setup.sh
#   ./setup.sh
#
# POST-INSTALLATION STEPS:
#   1. Configure Cloudflare Tunnel (see README.md Phase 4)
#   2. Set up Zero Trust Access policies
#   3. Configure Git with your GitHub credentials
#   4. Test the complete workflow
#
# AUTHOR: kyhomelab
# VERSION: 2.0
# LAST UPDATED: 2024-12-22
#
#===============================================================================

#-------------------------------------------------------------------------------
# Script Configuration
#-------------------------------------------------------------------------------

# Exit immediately if any command fails
# This prevents the script from continuing after an error
set -e

# Treat unset variables as an error
# Catches typos in variable names
set -u

# Pipe failures cause the whole pipeline to fail
# Without this, only the last command's exit status matters
set -o pipefail

# Define colors for output formatting
# These ANSI escape codes make the output easier to read
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (reset)

# Define the Node.js LTS version to install
# Update this when a new LTS version is released
NODE_LTS_VERSION="20"

# NVM version to install
NVM_VERSION="0.40.1"

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

# print_header - Displays a formatted section header
# Arguments:
#   $1 - Header text to display
print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

# print_step - Displays a step indicator
# Arguments:
#   $1 - Step description
print_step() {
    echo -e "${GREEN}[*]${NC} $1"
}

# print_info - Displays informational message
# Arguments:
#   $1 - Information text
print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# print_success - Displays a success message
# Arguments:
#   $1 - Success message
print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# print_error - Displays an error message
# Arguments:
#   $1 - Error message
print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# check_command - Verifies a command exists and is executable
# Arguments:
#   $1 - Command name to check
# Returns:
#   0 if command exists, 1 if not
check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# confirm_continue - Asks user to confirm before proceeding
# Arguments:
#   $1 - Prompt message
confirm_continue() {
    echo ""
    read -p "$1 (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Phase 1: System Updates and Essential Packages
#-------------------------------------------------------------------------------

install_system_updates() {
    print_header "Phase 1: System Updates"

    #---------------------------------------------------------------------------
    # Step 1.1: Update package list (apt update)
    #---------------------------------------------------------------------------
    # The 'apt update' command downloads package information from all configured
    # sources (repositories). This refreshes the local cache with the latest
    # available package versions.
    #
    # What it does:
    #   - Connects to repositories defined in /etc/apt/sources.list
    #   - Downloads package metadata (names, versions, dependencies)
    #   - Does NOT install or upgrade any packages
    #
    # Why it's needed:
    #   - Ensures we know about the latest available packages
    #   - Required before any install/upgrade operation
    #---------------------------------------------------------------------------
    print_step "Updating package list (apt update)..."
    print_info "This downloads the latest package information from repositories"

    sudo apt-get update
    # apt-get is preferred over apt in scripts for stable output formatting

    print_success "Package list updated"

    #---------------------------------------------------------------------------
    # Step 1.2: Upgrade installed packages (apt upgrade)
    #---------------------------------------------------------------------------
    # The 'apt upgrade' command installs available upgrades for all currently
    # installed packages. It downloads and installs newer versions.
    #
    # Flags explained:
    #   -y : Automatic yes to prompts (non-interactive)
    #        Without this, apt would pause and ask for confirmation
    #
    # What it does:
    #   - Compares installed packages to available versions
    #   - Downloads newer versions where available
    #   - Installs the updates, replacing old versions
    #   - May require a reboot for kernel updates
    #
    # Why it's needed:
    #   - Security patches fix known vulnerabilities
    #   - Bug fixes improve stability
    #   - Best practice to update before installing new software
    #---------------------------------------------------------------------------
    print_step "Upgrading installed packages (apt upgrade -y)..."
    print_info "This installs security patches and updates for all packages"

    sudo apt-get upgrade -y

    print_success "System packages upgraded"

    #---------------------------------------------------------------------------
    # Step 1.3: Install essential utilities
    #---------------------------------------------------------------------------
    # These packages provide commonly needed tools that may not be included
    # in a minimal Ubuntu Server installation.
    #
    # Package purposes:
    #   curl      - Transfer data from/to servers (HTTP, FTP, etc.)
    #               Used to download installation scripts
    #   wget      - Download files from the web
    #               Alternative to curl, some scripts prefer it
    #   vim       - Advanced text editor (vi improved)
    #               Powerful editor for experienced users
    #   nano      - Simple text editor
    #               Beginner-friendly editor
    #   htop      - Interactive process viewer
    #               Better alternative to 'top' for monitoring
    #   net-tools - Network utilities (ifconfig, netstat, etc.)
    #               Classic networking tools, still useful
    #   unzip     - Extract .zip archives
    #               Common archive format
    #   jq        - Command-line JSON processor
    #               Useful for parsing API responses
    #
    # Flags explained:
    #   -y : Automatic yes to prompts
    #---------------------------------------------------------------------------
    print_step "Installing essential utilities..."
    print_info "Packages: curl, wget, vim, nano, htop, net-tools, unzip, jq"

    sudo apt-get install -y \
        curl \
        wget \
        vim \
        nano \
        htop \
        net-tools \
        unzip \
        jq

    print_success "Essential utilities installed"
}

#-------------------------------------------------------------------------------
# Phase 2: Install Git
#-------------------------------------------------------------------------------

install_git() {
    print_header "Phase 2: Git Installation"

    #---------------------------------------------------------------------------
    # Check if Git is already installed
    #---------------------------------------------------------------------------
    if check_command git; then
        print_info "Git is already installed: $(git --version)"
    else
        #-----------------------------------------------------------------------
        # Install Git
        #-----------------------------------------------------------------------
        # Git is a distributed version control system. It's essential for:
        #   - Tracking changes to your code
        #   - Collaborating with others
        #   - Backing up code to GitHub/GitLab
        #   - Managing different versions of projects
        #
        # Ubuntu's package manager provides a stable version of Git.
        #-----------------------------------------------------------------------
        print_step "Installing Git..."

        sudo apt-get install -y git

        print_success "Git installed: $(git --version)"
    fi

    #---------------------------------------------------------------------------
    # Display Git configuration instructions
    #---------------------------------------------------------------------------
    print_info "Configure Git after installation with:"
    echo "    git config --global user.name \"Your Name\""
    echo "    git config --global user.email \"your-email@example.com\""
}

#-------------------------------------------------------------------------------
# Phase 3: Install Node.js via NVM
#-------------------------------------------------------------------------------

install_nodejs() {
    print_header "Phase 3: Node.js Installation (via NVM)"

    #---------------------------------------------------------------------------
    # Step 3.1: Install NVM (Node Version Manager)
    #---------------------------------------------------------------------------
    # NVM allows you to install and manage multiple Node.js versions.
    # This is preferable to system package manager installation because:
    #   - Easy to switch between Node.js versions
    #   - No sudo required for global npm packages
    #   - Simple upgrades to newer Node.js versions
    #
    # The installation script:
    #   - Downloads from GitHub (official nvm-sh repository)
    #   - Installs to ~/.nvm directory
    #   - Adds initialization code to shell profile
    #
    # Security note:
    #   Piping to bash executes remote code. The NVM project is well-established
    #   and widely used. For extra security, you could download and inspect first.
    #---------------------------------------------------------------------------

    # Check if NVM is already installed by looking for the directory
    if [ -d "$HOME/.nvm" ]; then
        print_info "NVM directory exists, checking installation..."
    fi

    print_step "Installing NVM (Node Version Manager) v${NVM_VERSION}..."
    print_info "NVM allows managing multiple Node.js versions"

    # Download and execute the NVM installation script
    # -o- : Output to stdout (not a file)
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash

    print_success "NVM installation script completed"

    #---------------------------------------------------------------------------
    # Step 3.2: Load NVM into current shell session
    #---------------------------------------------------------------------------
    # The NVM install script modifies ~/.bashrc, but those changes aren't
    # active in our current session. We need to manually load NVM.
    #
    # NVM_DIR: Environment variable pointing to NVM installation
    # nvm.sh:  The main NVM script that provides the 'nvm' command
    #---------------------------------------------------------------------------
    print_step "Loading NVM into current session..."

    export NVM_DIR="$HOME/.nvm"

    # Source the NVM script if it exists
    # [ -s "$file" ] checks if file exists and has size > 0
    # \. is equivalent to 'source' - executes the script in current shell
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Also load NVM bash completion for tab-completion
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    #---------------------------------------------------------------------------
    # Step 3.3: Install Node.js LTS version
    #---------------------------------------------------------------------------
    # LTS (Long Term Support) versions are recommended for production use.
    # They receive security updates and bug fixes for an extended period.
    #
    # Current LTS schedule (as of 2024):
    #   - Node 20.x: Active LTS until April 2026
    #   - Node 22.x: Will become LTS in October 2024
    #
    # The 'nvm install' command:
    #   - Downloads the specified Node.js version
    #   - Compiles if necessary (rare on supported platforms)
    #   - Sets it as the default version
    #---------------------------------------------------------------------------
    print_step "Installing Node.js LTS (v${NODE_LTS_VERSION})..."
    print_info "LTS versions receive long-term security updates"

    nvm install "${NODE_LTS_VERSION}"

    # Set this version as the default for new shells
    nvm alias default "${NODE_LTS_VERSION}"

    print_success "Node.js installed: $(node --version)"
    print_success "npm installed: $(npm --version)"
}

#-------------------------------------------------------------------------------
# Phase 4: Install Gemini CLI
#-------------------------------------------------------------------------------

install_gemini_cli() {
    print_header "Phase 4: Gemini CLI Installation"

    #---------------------------------------------------------------------------
    # Ensure NVM is loaded
    #---------------------------------------------------------------------------
    # NVM might not be loaded if this function is called separately
    if ! check_command nvm; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    #---------------------------------------------------------------------------
    # Install Gemini CLI globally
    #---------------------------------------------------------------------------
    # npm install -g installs packages globally, making them available
    # as commands from anywhere in the terminal.
    #
    # Flags:
    #   -g : Global installation (not project-specific)
    #
    # @google/gemini-cli:
    #   - Official Google package for Gemini AI interaction
    #   - Provides 'gemini' command for CLI access
    #   - Requires Google account authentication on first run
    #---------------------------------------------------------------------------
    print_step "Installing Gemini CLI globally..."
    print_info "This provides the 'gemini' command for AI assistance"

    npm install -g @google/gemini-cli

    print_success "Gemini CLI installed"
    print_info "Run 'gemini' to authenticate and start using"
}

#-------------------------------------------------------------------------------
# Phase 5: Install code-server (VS Code in Browser)
#-------------------------------------------------------------------------------

install_code_server() {
    print_header "Phase 5: code-server Installation"

    #---------------------------------------------------------------------------
    # Install code-server
    #---------------------------------------------------------------------------
    # code-server runs VS Code on a server and allows access through a browser.
    # This is the core of our remote development environment.
    #
    # The install script:
    #   - Detects the Linux distribution
    #   - Downloads the appropriate package
    #   - Installs dependencies
    #   - Creates systemd service files
    #
    # Curl flags:
    #   -f : Fail silently on HTTP errors (no output on 404, etc.)
    #   -s : Silent mode (no progress meter)
    #   -S : Show errors when -s is used
    #   -L : Follow redirects (important for GitHub releases)
    #---------------------------------------------------------------------------
    print_step "Installing code-server (VS Code in browser)..."
    print_info "This provides a full VS Code experience in your web browser"

    curl -fsSL https://code-server.dev/install.sh | sh

    print_success "code-server installed"

    #---------------------------------------------------------------------------
    # Enable and start code-server as a systemd service
    #---------------------------------------------------------------------------
    # systemctl manages system services (daemons) on modern Linux.
    #
    # Commands:
    #   enable    : Configure service to start automatically at boot
    #   --now     : Also start the service immediately (combines enable + start)
    #   @$USER    : Run the service as the current user (not root)
    #               This is a systemd "template unit" that creates a
    #               user-specific instance of the service
    #
    # Why run as user (not root):
    #   - Follows principle of least privilege
    #   - Extensions and settings are per-user
    #   - More secure if service is compromised
    #---------------------------------------------------------------------------
    print_step "Enabling code-server service to start at boot..."
    print_info "Service will run as user: $USER"

    sudo systemctl enable --now "code-server@$USER"

    print_success "code-server service enabled and started"

    #---------------------------------------------------------------------------
    # Display service status
    #---------------------------------------------------------------------------
    print_step "Checking code-server status..."
    sudo systemctl status "code-server@$USER" --no-pager || true
    # || true prevents script from exiting if status shows warnings

    #---------------------------------------------------------------------------
    # Display configuration information
    #---------------------------------------------------------------------------
    echo ""
    print_info "code-server configuration file: ~/.config/code-server/config.yaml"
    print_info "Default password is in the config file"
    print_info "code-server binds to localhost:8080 by default"
}

#-------------------------------------------------------------------------------
# Phase 6: Install Cloudflared
#-------------------------------------------------------------------------------

install_cloudflared() {
    print_header "Phase 6: Cloudflared Installation"

    #---------------------------------------------------------------------------
    # Step 6.1: Add Cloudflare's GPG key
    #---------------------------------------------------------------------------
    # APT uses GPG signatures to verify package authenticity.
    # We need to add Cloudflare's public key to trust their packages.
    #
    # mkdir -p --mode=0755:
    #   Creates the keyrings directory with proper permissions
    #   -p : Create parent directories if needed, no error if exists
    #   --mode=0755 : rwxr-xr-x (readable by all, writable by owner)
    #
    # curl | tee:
    #   Downloads the key and writes it to the keyring location
    #   tee writes to both stdout and file (stdout redirected to /dev/null)
    #---------------------------------------------------------------------------
    print_step "Adding Cloudflare GPG key..."
    print_info "This allows APT to verify Cloudflare packages are authentic"

    sudo mkdir -p --mode=0755 /usr/share/keyrings

    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | \
        sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

    print_success "Cloudflare GPG key added"

    #---------------------------------------------------------------------------
    # Step 6.2: Add Cloudflare APT repository
    #---------------------------------------------------------------------------
    # This adds Cloudflare's package repository to APT's sources.
    #
    # Repository line format:
    #   deb [options] URL distribution component
    #
    # signed-by: Specifies which GPG key to use for verification
    # jammy: Ubuntu 22.04 codename (update for other versions)
    # main: Repository component (standard packages)
    #
    # The echo | tee pattern writes the line to the sources file.
    #---------------------------------------------------------------------------
    print_step "Adding Cloudflare APT repository..."

    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | \
        sudo tee /etc/apt/sources.list.d/cloudflared.list

    print_success "Cloudflare repository added"

    #---------------------------------------------------------------------------
    # Step 6.3: Update package list and install cloudflared
    #---------------------------------------------------------------------------
    # After adding a new repository, we need to update the package list
    # to fetch information about available packages from that repository.
    #---------------------------------------------------------------------------
    print_step "Updating package list with Cloudflare repository..."

    sudo apt-get update

    print_step "Installing cloudflared..."
    print_info "cloudflared creates secure tunnels to Cloudflare's network"

    sudo apt-get install -y cloudflared

    print_success "cloudflared installed: $(cloudflared --version)"

    #---------------------------------------------------------------------------
    # Display next steps for tunnel configuration
    #---------------------------------------------------------------------------
    echo ""
    print_info "Cloudflared is installed but not configured."
    print_info "To set up the tunnel, see README.md Phase 4 for:"
    echo "    1. cloudflared tunnel login"
    echo "    2. cloudflared tunnel create <tunnel-name>"
    echo "    3. Configure ~/.cloudflared/config.yml"
    echo "    4. sudo cloudflared service install"
}

#-------------------------------------------------------------------------------
# Phase 7: Configure Firewall (UFW)
#-------------------------------------------------------------------------------

configure_firewall() {
    print_header "Phase 7: Firewall Configuration (UFW)"

    #---------------------------------------------------------------------------
    # UFW (Uncomplicated Firewall) Configuration
    #---------------------------------------------------------------------------
    # UFW is a user-friendly interface for iptables, the Linux firewall.
    # It simplifies firewall management with easy-to-understand commands.
    #
    # Our security model:
    #   - DENY all incoming connections by default
    #   - ALLOW all outgoing connections (needed for updates, tunnels)
    #   - Only ALLOW SSH (port 22) for local network access
    #   - code-server (8080) is NOT exposed - accessed via tunnel only
    #---------------------------------------------------------------------------

    print_step "Configuring UFW default policies..."

    #---------------------------------------------------------------------------
    # Set default policies
    #---------------------------------------------------------------------------
    # default deny incoming:
    #   Blocks ALL incoming connections unless explicitly allowed
    #   This is the foundation of our security - whitelist approach
    #
    # default allow outgoing:
    #   Allows the VM to initiate connections to the internet
    #   Needed for: apt updates, npm packages, tunnel connections
    #---------------------------------------------------------------------------
    print_info "Setting default policy: deny incoming connections"
    sudo ufw default deny incoming

    print_info "Setting default policy: allow outgoing connections"
    sudo ufw default allow outgoing

    #---------------------------------------------------------------------------
    # Allow SSH connections
    #---------------------------------------------------------------------------
    # 'ufw allow ssh' is equivalent to 'ufw allow 22/tcp'
    # SSH is needed for:
    #   - Initial setup and configuration
    #   - Backup access via Tailscale
    #   - Troubleshooting when tunnel is down
    #
    # Note: SSH should only be accessible from local network or VPN,
    # not directly from the internet. The router should NOT forward port 22.
    #---------------------------------------------------------------------------
    print_step "Allowing SSH connections (port 22)..."
    sudo ufw allow ssh

    print_success "SSH allowed through firewall"

    #---------------------------------------------------------------------------
    # Enable UFW
    #---------------------------------------------------------------------------
    # 'ufw enable' activates the firewall with configured rules.
    # The --force flag bypasses the confirmation prompt.
    #
    # Warning: If you're connected via SSH and misconfigure rules,
    # you could lock yourself out. That's why we allow SSH first.
    #---------------------------------------------------------------------------
    print_step "Enabling UFW firewall..."
    print_info "This may show a warning about SSH - rules are already configured"

    sudo ufw --force enable

    print_success "UFW firewall enabled"

    #---------------------------------------------------------------------------
    # Display firewall status
    #---------------------------------------------------------------------------
    print_step "Current firewall status:"
    sudo ufw status verbose

    echo ""
    print_info "Note: Port 8080 (code-server) is NOT exposed"
    print_info "Access is via Cloudflare Tunnel only (outbound connection)"
}

#-------------------------------------------------------------------------------
# Phase 8: Post-Installation Summary
#-------------------------------------------------------------------------------

show_summary() {
    print_header "Installation Complete!"

    echo "The following components have been installed and configured:"
    echo ""
    echo "  System:"
    echo "    - Ubuntu packages updated"
    echo "    - Essential utilities installed (curl, wget, vim, nano, htop, etc.)"
    echo ""
    echo "  Development Tools:"
    echo "    - Git: $(git --version 2>/dev/null || echo 'Not found')"
    echo "    - NVM: $(nvm --version 2>/dev/null || echo 'Not found - reload shell')"
    echo "    - Node.js: $(node --version 2>/dev/null || echo 'Not found - reload shell')"
    echo "    - npm: $(npm --version 2>/dev/null || echo 'Not found - reload shell')"
    echo ""
    echo "  Services:"
    echo "    - code-server: $(code-server --version 2>/dev/null | head -1 || echo 'Installed')"
    echo "    - cloudflared: $(cloudflared --version 2>/dev/null || echo 'Installed')"
    echo ""
    echo "  Security:"
    echo "    - UFW firewall enabled (SSH allowed, other incoming blocked)"
    echo ""

    print_header "Next Steps"

    echo "1. RELOAD YOUR SHELL to activate NVM:"
    echo "   source ~/.bashrc"
    echo ""
    echo "2. Configure Git with your identity:"
    echo "   git config --global user.name \"Your Name\""
    echo "   git config --global user.email \"your-email@example.com\""
    echo ""
    echo "3. Set up Cloudflare Tunnel (see README.md Phase 4):"
    echo "   cloudflared tunnel login"
    echo "   cloudflared tunnel create gemini-cli-tunnel"
    echo "   # Configure ~/.cloudflared/config.yml"
    echo "   sudo cloudflared service install"
    echo ""
    echo "4. Configure Zero Trust Access in Cloudflare dashboard"
    echo ""
    echo "5. Generate SSH key for GitHub:"
    echo "   ssh-keygen -t ed25519 -C \"github-gemini-cli-vm\""
    echo ""
    echo "For complete instructions, see: README.md"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          GEMINI CLI VM SETUP SCRIPT v2.0                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "This script will install and configure:"
    echo "  - System updates and essential packages"
    echo "  - Git version control"
    echo "  - Node.js via NVM"
    echo "  - Gemini CLI"
    echo "  - code-server (VS Code in browser)"
    echo "  - cloudflared (Cloudflare Tunnel)"
    echo "  - UFW firewall configuration"
    echo ""

    confirm_continue "Do you want to proceed with the installation?"

    # Record start time
    START_TIME=$(date +%s)

    # Execute installation phases
    install_system_updates
    install_git
    install_nodejs
    install_gemini_cli
    install_code_server
    install_cloudflared
    configure_firewall

    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))

    show_summary

    echo -e "${GREEN}Installation completed in ${MINUTES}m ${SECONDS}s${NC}"
    echo ""
}

# Run main function
main "$@"
