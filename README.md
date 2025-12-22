# Gemini CLI VM: Complete Implementation Guide

A comprehensive, step-by-step guide for setting up a remotely accessible Gemini CLI environment on a Proxmox virtual machine with secure access via Cloudflare Tunnel and Zero Trust.

## Table of Contents

- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Phase 1: VM Provisioning & OS Setup](#phase-1-vm-provisioning--os-setup)
- [Phase 2: Initial System Configuration](#phase-2-initial-system-configuration)
- [Phase 3: Core Software Installation](#phase-3-core-software-installation)
- [Phase 4: Cloudflare Tunnel & Zero Trust Configuration](#phase-4-cloudflare-tunnel--zero-trust-configuration)
- [Phase 5: Git & Project Setup](#phase-5-git--project-setup)
- [Phase 6: Testing & Verification](#phase-6-testing--verification)
- [Maintenance & Troubleshooting](#maintenance--troubleshooting)

---

## Project Overview

This project creates a secure, remotely accessible Gemini CLI environment for:
- Portfolio building and technical write-ups
- Research and documentation
- Secure remote development via browser-based VS Code

**Architecture:**
- **Host:** Proxmox VE hypervisor
- **VM:** Ubuntu Server LTS
- **Primary Access:** Cloudflare Tunnel with Zero Trust authentication
- **Backup Access:** Tailscale VPN
- **Development Environment:** VS Code Server (code-server)

---

## Prerequisites

Before starting, ensure you have:

- [ ] Proxmox VE installed and accessible
- [ ] Ubuntu Server LTS ISO downloaded
- [ ] Cloudflare account (free tier works)
- [ ] Domain registered and added to Cloudflare (for Zero Trust)
- [ ] GitHub account (for SSH key authentication)
- [ ] Tailscale account (optional, for backup access)

---

## Phase 1: VM Provisioning & OS Setup

### 1.1 Create Virtual Machine in Proxmox

#### Step 1: Access Proxmox Web Interface
Open your browser and navigate to your Proxmox server:
```
https://<proxmox-ip>:8006
```

#### Step 2: Create New VM
1. Click **"Create VM"** in the top-right corner
2. Configure the following settings:

**General Tab:**
| Setting | Value |
|---------|-------|
| Node | Select your Proxmox node |
| VM ID | Auto-assigned or choose (e.g., 100) |
| Name | `gemini-cli-vm` |

**OS Tab:**
| Setting | Value |
|---------|-------|
| ISO image | Select your Ubuntu Server LTS ISO |
| Type | Linux |
| Version | 6.x - 2.6 Kernel |

**System Tab:**
| Setting | Value |
|---------|-------|
| Machine | q35 |
| BIOS | OVMF (UEFI) |
| Add EFI Disk | Yes |
| SCSI Controller | VirtIO SCSI |

**Disks Tab:**
| Setting | Value |
|---------|-------|
| Bus/Device | SCSI |
| Storage | Select your storage pool |
| Disk size | 50 GiB |
| Discard | Enabled (if using SSD) |

**CPU Tab:**
| Setting | Value |
|---------|-------|
| Cores | 2 |
| Type | host |

**Memory Tab:**
| Setting | Value |
|---------|-------|
| Memory | 4096 MiB (4 GB) |

**Network Tab:**
| Setting | Value |
|---------|-------|
| Bridge | vmbr0 (or your network bridge) |
| Model | VirtIO (paravirtualized) |
| Firewall | Enabled |

3. Click **"Finish"** to create the VM

### 1.2 Install Ubuntu Server LTS

#### Step 1: Start the VM
```
Right-click VM → Start
Right-click VM → Console
```

#### Step 2: Ubuntu Installation Steps

1. **Language Selection**
   - Select: `English`

2. **Keyboard Configuration**
   - Layout: `English (US)`
   - Variant: `English (US)`

3. **Installation Type**
   - Select: `Ubuntu Server`

4. **Network Configuration**
   - Configure static IP (recommended):
     - Subnet: `192.168.1.0/24` (adjust for your network)
     - Address: `192.168.1.50` (choose an available IP)
     - Gateway: `192.168.1.1`
     - Name servers: `1.1.1.1,8.8.8.8`

5. **Proxy Configuration**
   - Leave blank (unless required)

6. **Mirror Configuration**
   - Accept default mirror

7. **Storage Configuration**
   - Select: `Use an entire disk`
   - Confirm: `Done` → `Continue`

8. **Profile Setup**
   | Field | Value |
   |-------|-------|
   | Your name | Your Full Name |
   | Server name | `gemini-cli-vm` |
   | Username | `kyhomelab` (or your preferred username) |
   | Password | Strong password |

9. **SSH Setup**
   - Select: `Install OpenSSH server`
   - Import SSH identity: `No` (we'll configure this manually)

10. **Featured Snaps**
    - Skip all selections → `Done`

11. **Installation Complete**
    - Select: `Reboot Now`
    - Remove installation media when prompted

---

## Phase 2: Initial System Configuration

Once Ubuntu is installed and you've logged in, perform these initial configuration steps.

### 2.1 Update System Packages

First, update the package list to get information about the newest versions of packages:

```bash
sudo apt update
```

**What this command does:**
- `sudo` - Runs the command with superuser (root) privileges
- `apt` - Advanced Package Tool, Ubuntu's package manager
- `update` - Downloads package information from all configured sources (repositories)

**Expected output:**
```
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://archive.ubuntu.com/ubuntu jammy-updates InRelease [119 kB]
...
Reading package lists... Done
```

Next, upgrade all installed packages to their latest versions:

```bash
sudo apt upgrade -y
```

**What this command does:**
- `upgrade` - Installs available upgrades of all packages
- `-y` - Automatically answers "yes" to prompts (non-interactive mode)

**Expected output:**
```
Reading package lists... Done
Building dependency tree... Done
Calculating upgrade... Done
The following packages will be upgraded:
...
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```

**Pro Tip:** You can combine both commands:
```bash
sudo apt update && sudo apt upgrade -y
```
The `&&` operator ensures the second command only runs if the first succeeds.

### 2.2 Install Essential Packages

Install commonly needed utilities:

```bash
sudo apt install -y curl wget vim nano htop net-tools
```

**What each package provides:**
| Package | Purpose |
|---------|---------|
| `curl` | Transfer data from/to servers (HTTP, FTP, etc.) |
| `wget` | Download files from the web |
| `vim` | Advanced text editor |
| `nano` | Simple text editor (beginner-friendly) |
| `htop` | Interactive process viewer |
| `net-tools` | Network utilities (ifconfig, netstat, etc.) |

### 2.3 Configure Timezone

Check current timezone:
```bash
timedatectl
```

**Expected output:**
```
               Local time: Sun 2024-12-22 10:30:00 UTC
           Universal time: Sun 2024-12-22 10:30:00 UTC
                 RTC time: Sun 2024-12-22 10:30:05
                Time zone: Etc/UTC (UTC, +0000)
```

List available timezones (search for yours):
```bash
timedatectl list-timezones | grep America
```

Set your timezone (example: Eastern Time):
```bash
sudo timedatectl set-timezone America/New_York
```

Verify the change:
```bash
timedatectl
```

### 2.4 Configure SSH Key-Based Authentication

**On your local machine (not the VM)**, generate an SSH key pair if you don't have one:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

**What this command does:**
- `ssh-keygen` - Tool to generate SSH keys
- `-t ed25519` - Specifies the key type (Ed25519 is modern and secure)
- `-C "comment"` - Adds a comment (usually your email) to identify the key

**Prompts and responses:**
```
Enter file in which to save the key (/home/user/.ssh/id_ed25519): [Press Enter for default]
Enter passphrase (empty for no passphrase): [Enter a strong passphrase]
Enter same passphrase again: [Confirm passphrase]
```

Copy your public key to the VM:

```bash
ssh-copy-id kyhomelab@192.168.1.50
```

**What this command does:**
- Copies your public key to the VM's `~/.ssh/authorized_keys` file
- Enables passwordless SSH login using your private key

**Alternative manual method:**

On your local machine, display your public key:
```bash
cat ~/.ssh/id_ed25519.pub
```

On the VM, create the SSH directory and authorized_keys file:
```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
```

Paste your public key, save, and set permissions:
```bash
chmod 600 ~/.ssh/authorized_keys
```

### 2.5 Secure SSH Configuration

Edit the SSH daemon configuration:
```bash
sudo nano /etc/ssh/sshd_config
```

Make the following changes (find and modify these lines):

```
# Disable root login
PermitRootLogin no

# Disable password authentication (after confirming key auth works!)
PasswordAuthentication no

# Enable public key authentication
PubkeyAuthentication yes

# Limit authentication attempts
MaxAuthTries 3

# Set idle timeout (300 seconds = 5 minutes)
ClientAliveInterval 300
ClientAliveCountMax 2
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

Test the configuration for syntax errors:
```bash
sudo sshd -t
```

If no errors, restart SSH:
```bash
sudo systemctl restart sshd
```

**What this command does:**
- `systemctl` - Controls the systemd system and service manager
- `restart` - Stops and starts the service
- `sshd` - The SSH daemon service

**IMPORTANT:** Before closing your current SSH session, open a new terminal and test the connection:
```bash
ssh kyhomelab@192.168.1.50
```

### 2.6 Configure Firewall (UFW)

UFW (Uncomplicated Firewall) provides a user-friendly interface for managing iptables.

Check UFW status:
```bash
sudo ufw status
```

**Expected output (if not configured):**
```
Status: inactive
```

Set default policies (deny incoming, allow outgoing):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**What these commands do:**
- `default deny incoming` - Blocks all incoming connections by default
- `default allow outgoing` - Allows all outgoing connections by default

Allow SSH connections:
```bash
sudo ufw allow ssh
```

This is equivalent to:
```bash
sudo ufw allow 22/tcp
```

Enable the firewall:
```bash
sudo ufw enable
```

**Warning prompt:**
```
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y
Firewall is active and enabled on system startup
```

Verify firewall status:
```bash
sudo ufw status verbose
```

**Expected output:**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

---

## Phase 3: Core Software Installation

### 3.1 Install Git

Git is essential for version control and managing your projects.

```bash
sudo apt install -y git
```

Verify installation:
```bash
git --version
```

**Expected output:**
```
git version 2.34.1
```

Configure Git with your identity:
```bash
git config --global user.name "Your Full Name"
git config --global user.email "your-email@example.com"
```

**What these commands do:**
- `--global` - Applies configuration to all repositories for the current user
- `user.name` - Sets your name for commit attribution
- `user.email` - Sets your email for commit attribution

Set default branch name:
```bash
git config --global init.defaultBranch main
```

Configure default editor (optional):
```bash
git config --global core.editor nano
```

View your Git configuration:
```bash
git config --list
```

### 3.2 Install Node.js via NVM

NVM (Node Version Manager) allows you to install and manage multiple Node.js versions.

Download and install NVM:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

**What this command does:**
- `curl -o-` - Downloads content and outputs to stdout
- `| bash` - Pipes the output to bash for execution
- The script installs NVM to `~/.nvm` and updates your shell profile

**Security Note:** Always review scripts before piping to bash. You can download and inspect first:
```bash
curl -o nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh
cat nvm-install.sh  # Review the script
bash nvm-install.sh
```

Load NVM into current session:
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

**Or simply restart your shell:**
```bash
source ~/.bashrc
```

Verify NVM installation:
```bash
nvm --version
```

**Expected output:**
```
0.40.1
```

Install Node.js LTS version:
```bash
nvm install --lts
```

**What this command does:**
- `--lts` - Installs the latest Long Term Support version
- LTS versions are recommended for production use

Verify Node.js installation:
```bash
node --version
npm --version
```

**Expected output:**
```
v20.18.0
10.8.2
```

### 3.3 Install Gemini CLI

Install the Gemini CLI globally using npm:

```bash
npm install -g @google/gemini-cli
```

**What this command does:**
- `npm install` - Installs a package
- `-g` - Installs globally (available system-wide)
- `@google/gemini-cli` - The official Gemini CLI package

Verify installation:
```bash
gemini --version
```

Initialize Gemini (first-time setup):
```bash
gemini
```

This will prompt you to authenticate with your Google account.

### 3.4 Install VS Code Server (code-server)

code-server provides a full VS Code experience in your browser.

Download and install code-server:
```bash
curl -fsSL https://code-server.dev/install.sh | sh
```

**What the flags mean:**
- `-f` - Fail silently on HTTP errors
- `-s` - Silent mode (no progress meter)
- `-S` - Show errors if -s is used
- `-L` - Follow redirects

Enable code-server to start on boot:
```bash
sudo systemctl enable --now code-server@$USER
```

**What this command does:**
- `enable` - Configures the service to start at boot
- `--now` - Also starts the service immediately
- `@$USER` - Runs the service as your user (not root)

Check service status:
```bash
sudo systemctl status code-server@$USER
```

**Expected output:**
```
● code-server@kyhomelab.service - code-server
     Loaded: loaded (/lib/systemd/system/code-server@.service; enabled)
     Active: active (running) since Sun 2024-12-22 10:45:00 EST
```

View code-server configuration:
```bash
cat ~/.config/code-server/config.yaml
```

**Default configuration:**
```yaml
bind-addr: 127.0.0.1:8080
auth: password
password: <random-generated-password>
cert: false
```

**Note:** code-server only binds to localhost by default. We'll access it through Cloudflare Tunnel.

### 3.5 Install Cloudflared

Cloudflared is the daemon that creates secure tunnels to Cloudflare.

Add Cloudflare's GPG key:
```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
```

Add the Cloudflare repository:
```bash
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
```

Update package list and install:
```bash
sudo apt update
sudo apt install -y cloudflared
```

Verify installation:
```bash
cloudflared --version
```

**Expected output:**
```
cloudflared version 2024.12.0 (built 2024-12-01)
```

---

## Phase 4: Cloudflare Tunnel & Zero Trust Configuration

This phase configures secure remote access via Cloudflare Tunnel with Zero Trust authentication.

### 4.1 Authenticate Cloudflared

Authenticate cloudflared with your Cloudflare account:

```bash
cloudflared tunnel login
```

**What happens:**
1. A URL is displayed in the terminal
2. Open this URL in a browser
3. Select the domain you want to use for the tunnel
4. Cloudflare stores a certificate in `~/.cloudflared/cert.pem`

**Expected terminal output:**
```
Please open the following URL and log in with your Cloudflare account:

https://dash.cloudflare.com/argotunnel?callback=...

Leave cloudflared running to download the cert automatically.
```

After authorizing, you'll see:
```
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
/home/kyhomelab/.cloudflared/cert.pem
```

### 4.2 Create a Tunnel

Create a new named tunnel:

```bash
cloudflared tunnel create gemini-cli-tunnel
```

**What this command does:**
- Creates a new tunnel with the name `gemini-cli-tunnel`
- Generates a tunnel ID and credentials file
- Stores credentials in `~/.cloudflared/<tunnel-id>.json`

**Expected output:**
```
Tunnel credentials written to /home/kyhomelab/.cloudflared/abc12345-6789-def0-1234-567890abcdef.json
Created tunnel gemini-cli-tunnel with id abc12345-6789-def0-1234-567890abcdef
```

**Save the tunnel ID** - you'll need it for configuration.

List your tunnels:
```bash
cloudflared tunnel list
```

### 4.3 Configure DNS for the Tunnel

Route your subdomain to the tunnel:

```bash
cloudflared tunnel route dns gemini-cli-tunnel code.yourdomain.com
```

**Replace `code.yourdomain.com` with your actual subdomain.**

**What this command does:**
- Creates a CNAME record in Cloudflare DNS
- Points `code.yourdomain.com` to your tunnel

**Expected output:**
```
Added CNAME code.yourdomain.com which will route to this tunnel
```

### 4.4 Create Tunnel Configuration File

Create the cloudflared configuration:

```bash
nano ~/.cloudflared/config.yml
```

Add the following configuration:

```yaml
# Cloudflare Tunnel Configuration
tunnel: abc12345-6789-def0-1234-567890abcdef  # Replace with your tunnel ID
credentials-file: /home/kyhomelab/.cloudflared/abc12345-6789-def0-1234-567890abcdef.json

# Ingress rules define how traffic is routed
ingress:
  # Route code.yourdomain.com to VS Code Server
  - hostname: code.yourdomain.com
    service: http://localhost:8080

  # Catch-all rule (required)
  - service: http_status:404
```

**Configuration explained:**
| Field | Purpose |
|-------|---------|
| `tunnel` | Your unique tunnel ID |
| `credentials-file` | Path to tunnel credentials |
| `ingress` | Rules for routing traffic |
| `hostname` | The public hostname to match |
| `service` | Where to route matched traffic |

Save and exit.

Validate the configuration:
```bash
cloudflared tunnel ingress validate
```

**Expected output:**
```
Validating rules from /home/kyhomelab/.cloudflared/config.yml
OK
```

### 4.5 Test the Tunnel

Run the tunnel manually to test:

```bash
cloudflared tunnel run gemini-cli-tunnel
```

**Expected output:**
```
INF Starting tunnel tunnelID=abc12345-6789-def0-1234-567890abcdef
INF Connection established connIndex=0 connection=...
INF Connection established connIndex=1 connection=...
```

Open `https://code.yourdomain.com` in a browser. You should see the code-server login page.

Press `Ctrl+C` to stop the test.

### 4.6 Install Cloudflared as a System Service

Install cloudflared as a system service so it starts automatically:

```bash
sudo cloudflared service install
```

**What this command does:**
- Copies configuration to `/etc/cloudflared/`
- Creates a systemd service file
- Enables the service to start at boot

Start the service:
```bash
sudo systemctl start cloudflared
```

Check service status:
```bash
sudo systemctl status cloudflared
```

**Expected output:**
```
● cloudflared.service - cloudflared
     Loaded: loaded (/etc/systemd/system/cloudflared.service; enabled)
     Active: active (running) since Sun 2024-12-22 12:00:00 EST
```

### 4.7 Configure Cloudflare Zero Trust Access

Now we'll protect the tunnel with Cloudflare Zero Trust authentication.

#### Step 1: Access Zero Trust Dashboard

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click **"Zero Trust"** in the left sidebar
3. If first time, complete the Zero Trust onboarding

#### Step 2: Create an Access Application

1. Navigate to **Access** → **Applications**
2. Click **"Add an application"**
3. Select **"Self-hosted"**

Configure the application:

**Application Configuration:**
| Setting | Value |
|---------|-------|
| Application name | `VS Code Server` |
| Session Duration | `24 hours` |

**Application Domain:**
| Setting | Value |
|---------|-------|
| Subdomain | `code` |
| Domain | `yourdomain.com` |

Click **"Next"** to configure policies.

#### Step 3: Create Access Policy

**Policy Configuration:**
| Setting | Value |
|---------|-------|
| Policy name | `Allow Authorized Users` |
| Action | `Allow` |

**Configure Rules (Include):**

Choose your authentication method:

**Option A: Email-based (Simple)**
| Selector | Value |
|----------|-------|
| Emails | `your-email@example.com` |

**Option B: One-Time PIN (Recommended for personal use)**
| Selector | Value |
|----------|-------|
| Emails ending in | `@gmail.com` (or your email domain) |

**Option C: Identity Provider (Most Secure)**

First, configure an IdP under **Settings** → **Authentication**, then:
| Selector | Value |
|----------|-------|
| Login Methods | `Google` (or your configured IdP) |

Click **"Next"** and then **"Add application"**.

#### Step 4: Test Zero Trust Access

1. Open `https://code.yourdomain.com` in an incognito/private browser window
2. You should see the Cloudflare Access login page
3. Authenticate using your configured method
4. After authentication, you'll be redirected to code-server

### 4.8 Configure code-server Authentication (Optional)

Since Cloudflare Zero Trust handles authentication, you can optionally disable code-server's password:

```bash
nano ~/.config/code-server/config.yaml
```

Change authentication to none:
```yaml
bind-addr: 127.0.0.1:8080
auth: none
cert: false
```

Restart code-server:
```bash
sudo systemctl restart code-server@$USER
```

**Note:** Only do this if Zero Trust is properly configured. The tunnel ensures code-server is never directly exposed to the internet.

---

## Phase 5: Git & Project Setup

### 5.1 Generate SSH Key for GitHub

Generate a dedicated SSH key for GitHub:

```bash
ssh-keygen -t ed25519 -C "github-gemini-cli-vm" -f ~/.ssh/github_ed25519
```

**What the flags mean:**
- `-t ed25519` - Key type (most secure option)
- `-C "comment"` - Label to identify the key
- `-f ~/.ssh/github_ed25519` - Output file path

Start the SSH agent:
```bash
eval "$(ssh-agent -s)"
```

**Expected output:**
```
Agent pid 12345
```

Add the key to the agent:
```bash
ssh-add ~/.ssh/github_ed25519
```

Display the public key:
```bash
cat ~/.ssh/github_ed25519.pub
```

Copy this key and add it to GitHub:
1. Go to [GitHub SSH Keys Settings](https://github.com/settings/keys)
2. Click **"New SSH key"**
3. Title: `Gemini CLI VM`
4. Key type: `Authentication Key`
5. Paste the public key
6. Click **"Add SSH key"**

Configure SSH to use this key for GitHub:
```bash
nano ~/.ssh/config
```

Add:
```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_ed25519
    IdentitiesOnly yes
```

Test the connection:
```bash
ssh -T git@github.com
```

**Expected output:**
```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

### 5.2 Create Project Directory Structure

Create an organized directory structure:

```bash
mkdir -p ~/projects/{active,archive,sandbox}
mkdir -p ~/documents/{notes,exports}
```

**Directory purposes:**
| Directory | Purpose |
|-----------|---------|
| `~/projects/active` | Current projects |
| `~/projects/archive` | Completed projects |
| `~/projects/sandbox` | Experimental/testing |
| `~/documents/notes` | Notes and documentation |
| `~/documents/exports` | Exported content |

### 5.3 Clone Your Portfolio Repository

```bash
cd ~/projects/active
git clone git@github.com:yourusername/your-portfolio.git
```

Verify the clone:
```bash
ls -la your-portfolio
```

---

## Phase 6: Testing & Verification

### 6.1 Test Remote Access via Cloudflare Tunnel

1. **From a different network** (not your home network), open:
   ```
   https://code.yourdomain.com
   ```

2. Verify Zero Trust authentication prompts you to log in

3. After login, verify code-server loads correctly

4. Test file creation and editing in VS Code

### 6.2 Test Gemini CLI

Open a terminal in code-server and run:

```bash
gemini
```

Verify you can interact with Gemini.

### 6.3 Test Git Operations

Create a test file and push:

```bash
cd ~/projects/active/your-portfolio
echo "Test commit from Gemini CLI VM" >> test.txt
git add test.txt
git commit -m "Test: Verify Git push from Gemini CLI VM"
git push
```

Verify the commit appears on GitHub.

Clean up:
```bash
git rm test.txt
git commit -m "Clean up test file"
git push
```

### 6.4 Test Tailscale (Backup Access)

If you've configured Tailscale as backup access:

```bash
sudo apt install -y tailscale
sudo tailscale up
```

Follow the authentication URL, then verify connectivity:
```bash
tailscale status
```

---

## Maintenance & Troubleshooting

### Regular Maintenance Tasks

**Weekly: Update system packages**
```bash
sudo apt update && sudo apt upgrade -y
```

**Monthly: Review and clean up**
```bash
# Remove unused packages
sudo apt autoremove -y

# Clean package cache
sudo apt clean

# Check disk usage
df -h
```

### Useful Commands

**Check service statuses:**
```bash
sudo systemctl status code-server@$USER
sudo systemctl status cloudflared
```

**View logs:**
```bash
# code-server logs
journalctl -u code-server@$USER -f

# cloudflared logs
journalctl -u cloudflared -f
```

**Restart services:**
```bash
sudo systemctl restart code-server@$USER
sudo systemctl restart cloudflared
```

### Troubleshooting

**Issue: Cannot access code.yourdomain.com**
1. Check cloudflared is running: `sudo systemctl status cloudflared`
2. Check DNS propagation: `dig code.yourdomain.com`
3. Verify tunnel is connected: `cloudflared tunnel info gemini-cli-tunnel`

**Issue: Zero Trust login fails**
1. Check your email is in the allow list
2. Verify the Access Application is enabled
3. Check browser cookies/cache (try incognito)

**Issue: code-server shows blank page**
1. Check code-server is running: `sudo systemctl status code-server@$USER`
2. Check for port conflicts: `sudo lsof -i :8080`
3. Review code-server logs: `journalctl -u code-server@$USER --since "10 minutes ago"`

**Issue: Git push fails**
1. Verify SSH key is added to agent: `ssh-add -l`
2. Test GitHub connection: `ssh -T git@github.com`
3. Check SSH config: `cat ~/.ssh/config`

---

## Quick Reference

| Service | Command |
|---------|---------|
| Start code-server | `sudo systemctl start code-server@$USER` |
| Stop code-server | `sudo systemctl stop code-server@$USER` |
| Start cloudflared | `sudo systemctl start cloudflared` |
| Stop cloudflared | `sudo systemctl stop cloudflared` |
| View code-server config | `cat ~/.config/code-server/config.yaml` |
| View tunnel config | `cat ~/.cloudflared/config.yml` |
| List tunnels | `cloudflared tunnel list` |
| Check tunnel status | `cloudflared tunnel info <tunnel-name>` |

---

## Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- [code-server Documentation](https://coder.com/docs/code-server)
- [Gemini CLI Documentation](https://github.com/google/generative-ai-cli)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
