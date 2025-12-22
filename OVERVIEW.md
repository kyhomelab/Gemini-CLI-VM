# Project: Remotely Accessible & Personalized Gemini CLI Environment

## Executive Summary

This project establishes a secure, remotely accessible development environment centered around the Gemini CLI. The environment runs on an isolated virtual machine, accessible from anywhere through Cloudflare's Zero Trust network, providing a professional-grade setup for portfolio development, technical documentation, and AI-assisted research.

---

## Project Goals

### Primary Objectives
1. **Remote Accessibility** - Access development environment from any location via web browser
2. **Security First** - Implement Zero Trust authentication with no exposed ports
3. **AI Integration** - Leverage Gemini CLI for intelligent assistance with coding and writing tasks
4. **Isolation** - Keep the environment separate from production systems

### Use Cases
- Portfolio website development and maintenance
- Technical blog writing and documentation
- Code generation and review with AI assistance
- Research and note-taking with persistent storage
- Learning and experimentation in an isolated environment

---

## Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │      CLOUDFLARE NETWORK       │
                    │  ┌─────────────────────────┐  │
                    │  │    Zero Trust Access    │  │
                    │  │  (Authentication Layer) │  │
                    │  └───────────┬─────────────┘  │
                    │              │                │
                    │  ┌───────────▼─────────────┐  │
                    │  │   Cloudflare Tunnel     │  │
                    │  │ (Encrypted Connection)  │  │
                    │  └───────────┬─────────────┘  │
                    └──────────────┼────────────────┘
                                   │
                    ┌──────────────▼────────────────┐
                    │        HOME NETWORK           │
                    │  ┌─────────────────────────┐  │
                    │  │    PROXMOX VE HOST      │  │
                    │  │  ┌───────────────────┐  │  │
                    │  │  │  GEMINI CLI VM    │  │  │
                    │  │  │  ┌─────────────┐  │  │  │
                    │  │  │  │ cloudflared │  │  │  │
                    │  │  │  │     ▼       │  │  │  │
                    │  │  │  │ code-server │  │  │  │
                    │  │  │  │     ▼       │  │  │  │
                    │  │  │  │ Gemini CLI  │  │  │  │
                    │  │  │  │     ▼       │  │  │  │
                    │  │  │  │    Git      │  │  │  │
                    │  │  │  └─────────────┘  │  │  │
                    │  │  └───────────────────┘  │  │
                    │  └─────────────────────────┘  │
                    └───────────────────────────────┘
```

### Component Descriptions

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Proxmox VE** | Hypervisor hosting the VM | KVM-based virtualization |
| **Ubuntu Server LTS** | Base operating system | 22.04 LTS (Jammy Jellyfish) |
| **code-server** | Browser-based VS Code | Latest stable release |
| **Gemini CLI** | AI assistant interface | Google's official CLI tool |
| **cloudflared** | Secure tunnel daemon | Cloudflare's connector |
| **Zero Trust Access** | Authentication layer | Cloudflare Access |
| **Git + SSH** | Version control | GitHub integration |

---

## Network Architecture

### Traffic Flow

```
User Browser → Cloudflare Edge → Zero Trust Auth → Tunnel → cloudflared → localhost:8080 → code-server
```

### Detailed Flow Explanation

1. **User Request** - User navigates to `https://code.yourdomain.com`
2. **Edge Routing** - Cloudflare's global network receives the request
3. **Authentication** - Zero Trust checks if user is authenticated
   - If not: Redirects to login page (email/OTP/IdP)
   - If yes: Allows request through
4. **Tunnel Transport** - Request travels through encrypted Cloudflare Tunnel
5. **Local Delivery** - `cloudflared` daemon receives request on the VM
6. **Service Routing** - Traffic routed to `localhost:8080` (code-server)
7. **Response** - code-server renders VS Code in the browser

### Port Configuration

| Service | Bind Address | External Access |
|---------|--------------|-----------------|
| SSH | `0.0.0.0:22` | Local network only |
| code-server | `127.0.0.1:8080` | Via tunnel only |
| cloudflared | Outbound only | No listening ports |

**Key Security Feature:** No inbound ports are exposed to the internet. All external access flows through the Cloudflare Tunnel, which initiates outbound-only connections.

---

## Security Architecture

### Defense in Depth Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Network Perimeter                                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • No inbound firewall ports open                            │ │
│ │ • Outbound-only tunnel connections                          │ │
│ │ • Cloudflare DDoS protection                                │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Layer 2: Authentication                                          │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • Cloudflare Zero Trust (mandatory authentication)          │ │
│ │ • Identity Provider integration (Google, GitHub, etc.)      │ │
│ │ • Optional MFA enforcement                                  │ │
│ │ • Session management and timeout                            │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Layer 3: Transport Security                                      │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • TLS 1.3 encryption (Cloudflare managed)                   │ │
│ │ • Certificate automation                                    │ │
│ │ • HTTPS-only access                                         │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Layer 4: Host Security                                           │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • UFW firewall (default deny incoming)                      │ │
│ │ • SSH key-only authentication                               │ │
│ │ • Non-root service execution                                │ │
│ │ • Regular security updates                                  │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Layer 5: Application Security                                    │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • code-server binds to localhost only                       │ │
│ │ • Application-level authentication (optional second layer)  │ │
│ │ • Isolated VM environment                                   │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Security Principles Applied

| Principle | Implementation |
|-----------|----------------|
| **Zero Trust** | Every request authenticated via Cloudflare Access |
| **Least Privilege** | Services run as non-root user; minimal permissions |
| **Defense in Depth** | Multiple overlapping security controls |
| **Attack Surface Reduction** | No exposed ports; tunnel-only access |
| **Secure by Default** | SSH password auth disabled; key-only |
| **Encryption in Transit** | All traffic TLS encrypted |

---

## Access Methods

### Primary Access: Cloudflare Tunnel + Zero Trust

**Best for:** Regular daily use from any network

| Attribute | Value |
|-----------|-------|
| URL | `https://code.yourdomain.com` |
| Authentication | Zero Trust (email/IdP) |
| Encryption | TLS 1.3 |
| Requirements | Modern web browser |

**Advantages:**
- No client software required
- Works through corporate firewalls
- Automatic TLS certificate management
- DDoS protection included
- Access from any device

### Backup Access: Tailscale VPN

**Best for:** Direct SSH access, maintenance, troubleshooting

| Attribute | Value |
|-----------|-------|
| Access | Direct IP via Tailscale network |
| Authentication | Tailscale SSO + SSH keys |
| Encryption | WireGuard |
| Requirements | Tailscale client installed |

**Advantages:**
- Direct shell access
- Lower latency for some operations
- Independent of Cloudflare
- Good for file transfers (scp/sftp)

### Access Decision Matrix

| Scenario | Recommended Access |
|----------|-------------------|
| Writing code | Cloudflare Tunnel (code-server) |
| Quick file edit | Cloudflare Tunnel (code-server) |
| System administration | Tailscale (SSH) |
| Troubleshooting | Tailscale (SSH) |
| Teaching/Demo | Cloudflare Tunnel (shareable URL) |
| Corporate network | Cloudflare Tunnel (works through firewalls) |

---

## VM Specifications

### Resource Allocation

| Resource | Specification | Rationale |
|----------|---------------|-----------|
| vCPUs | 2 cores | Sufficient for code-server and CLI tools |
| RAM | 4 GB | Comfortable for VS Code and multiple terminals |
| Storage | 50 GB | Room for projects, node_modules, and growth |
| Network | VirtIO | Best performance for virtual NICs |

### Software Stack

```
Operating System
└── Ubuntu Server 22.04 LTS
    ├── System Services
    │   ├── systemd (service management)
    │   ├── ufw (firewall)
    │   └── openssh-server (SSH access)
    │
    ├── Development Tools
    │   ├── git (version control)
    │   ├── nvm (Node.js version manager)
    │   ├── Node.js LTS (JavaScript runtime)
    │   └── npm (package manager)
    │
    ├── Application Services
    │   ├── code-server (VS Code in browser)
    │   └── Gemini CLI (AI assistant)
    │
    └── Network Services
        ├── cloudflared (Cloudflare Tunnel)
        └── tailscale (optional VPN)
```

---

## File System Layout

```
/home/kyhomelab/
├── .cloudflared/           # Cloudflare tunnel configuration
│   ├── cert.pem           # Authentication certificate
│   ├── config.yml         # Tunnel routing configuration
│   └── <tunnel-id>.json   # Tunnel credentials
│
├── .config/
│   └── code-server/
│       └── config.yaml    # code-server settings
│
├── .ssh/
│   ├── authorized_keys    # Allowed SSH public keys
│   ├── config             # SSH client configuration
│   ├── github_ed25519     # GitHub private key
│   └── github_ed25519.pub # GitHub public key
│
├── .nvm/                  # Node Version Manager
│   └── versions/
│       └── node/          # Installed Node.js versions
│
├── projects/              # Project workspace
│   ├── active/           # Current projects
│   ├── archive/          # Completed projects
│   └── sandbox/          # Experimental work
│
└── documents/             # Documentation
    ├── notes/            # Personal notes
    └── exports/          # Exported content
```

---

## Service Configuration

### code-server

**Configuration file:** `~/.config/code-server/config.yaml`

```yaml
# Bind to localhost only - tunnel handles external access
bind-addr: 127.0.0.1:8080

# Authentication handled by Zero Trust
auth: none

# TLS handled by Cloudflare
cert: false
```

### cloudflared

**Configuration file:** `~/.cloudflared/config.yml`

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/kyhomelab/.cloudflared/<tunnel-id>.json

ingress:
  # Route VS Code traffic
  - hostname: code.yourdomain.com
    service: http://localhost:8080

  # Required catch-all
  - service: http_status:404
```

### UFW Firewall

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere      # SSH access
```

**Note:** Port 8080 is NOT opened externally - it's accessed via localhost through the tunnel.

---

## Maintenance Schedule

### Daily (Automatic)
- Cloudflare Tunnel health monitoring
- Service uptime monitoring

### Weekly
- `sudo apt update && sudo apt upgrade -y` - Security patches
- Review cloudflared logs for anomalies
- Verify Zero Trust access logs

### Monthly
- `sudo apt autoremove -y` - Clean unused packages
- Review and rotate any API keys/tokens
- Audit Zero Trust access policies
- Check disk usage and clean if needed

### Quarterly
- Review and update Node.js LTS version
- Update code-server to latest release
- Review security configuration
- Test backup access method (Tailscale)

---

## Disaster Recovery

### Backup Strategy

| Component | Backup Method | Frequency |
|-----------|---------------|-----------|
| Projects | Git push to GitHub | Per commit |
| Configuration | Documented in this repo | On change |
| VM State | Proxmox snapshot | Weekly |
| Tunnel credentials | Stored in Cloudflare | N/A (managed) |

### Recovery Procedures

**Scenario 1: code-server not responding**
```bash
sudo systemctl restart code-server@$USER
journalctl -u code-server@$USER --since "10 minutes ago"
```

**Scenario 2: Tunnel disconnected**
```bash
sudo systemctl restart cloudflared
cloudflared tunnel info gemini-cli-tunnel
```

**Scenario 3: Complete VM failure**
1. Restore from Proxmox snapshot (or rebuild from README)
2. Re-authenticate cloudflared: `cloudflared tunnel login`
3. Restore tunnel credentials from backup
4. Clone projects from GitHub
5. Verify services start correctly

---

## Future Enhancements

### Planned
- [ ] Automated backup script for configurations
- [ ] Monitoring/alerting for service health
- [ ] Custom VS Code extensions bundle

### Potential
- [ ] Additional AI tool integrations (Claude, ChatGPT)
- [ ] Jupyter notebook support for data analysis
- [ ] Container support (Docker) for development

---

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- [code-server Documentation](https://coder.com/docs/code-server)
- [Gemini CLI Repository](https://github.com/google/generative-ai-cli)
- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
