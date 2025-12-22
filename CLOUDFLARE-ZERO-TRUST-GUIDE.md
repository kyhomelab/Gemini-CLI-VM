# Cloudflare Zero Trust Configuration Guide

A comprehensive, step-by-step guide for configuring Cloudflare Tunnel and Zero Trust Access to securely expose your code-server instance to the internet.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Part 1: Understanding Zero Trust Architecture](#part-1-understanding-zero-trust-architecture)
- [Part 2: Cloudflare Account Setup](#part-2-cloudflare-account-setup)
- [Part 3: Creating and Configuring the Tunnel](#part-3-creating-and-configuring-the-tunnel)
- [Part 4: Zero Trust Access Policies](#part-4-zero-trust-access-policies)
- [Part 5: Testing and Verification](#part-5-testing-and-verification)
- [Part 6: Advanced Configuration](#part-6-advanced-configuration)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting this guide, ensure you have:

- [ ] Completed the main README.md phases 1-3 (VM setup and software installation)
- [ ] cloudflared installed on your VM (`cloudflared --version`)
- [ ] A Cloudflare account (free tier is sufficient)
- [ ] A domain name added to Cloudflare (DNS managed by Cloudflare)
- [ ] code-server running on the VM (`sudo systemctl status code-server@$USER`)

---

## Part 1: Understanding Zero Trust Architecture

### What is Zero Trust?

Zero Trust is a security model based on the principle: **"Never trust, always verify."**

Traditional security models trust users inside the network perimeter. Zero Trust:
- Treats every access request as potentially hostile
- Requires authentication for every request
- Grants minimal necessary access
- Continuously validates trust

### How Cloudflare Zero Trust Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER'S BROWSER                                     │
│                                                                              │
│  1. User navigates to https://code.yourdomain.com                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLOUDFLARE EDGE NETWORK                               │
│                                                                              │
│  2. Cloudflare receives request at nearest edge location                    │
│     (200+ data centers worldwide for low latency)                           │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    ZERO TRUST ACCESS CHECK                           │    │
│  │                                                                      │    │
│  │  3. Is user authenticated?                                          │    │
│  │     ├── NO  → Redirect to login page                                │    │
│  │     │         (Email OTP, Google, GitHub, etc.)                     │    │
│  │     │                                                                │    │
│  │     └── YES → Check access policies                                 │    │
│  │               ├── Policy ALLOWS → Continue to step 4                │    │
│  │               └── Policy DENIES → Show access denied page           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  4. Forward request through Cloudflare Tunnel                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                            (Encrypted tunnel)
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              YOUR VM                                         │
│                                                                              │
│  5. cloudflared daemon receives request                                     │
│     Routes to localhost:8080 (code-server)                                  │
│                                                                              │
│  6. code-server serves VS Code interface                                    │
│                                                                              │
│  7. Response travels back through tunnel → Cloudflare → User's browser      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **No open ports** | Your VM has no inbound ports exposed to the internet |
| **Encrypted transport** | All traffic uses TLS 1.3 encryption |
| **Identity verification** | Every user must authenticate |
| **Centralized access logs** | All access attempts logged in Cloudflare dashboard |
| **DDoS protection** | Cloudflare's network absorbs attacks |
| **Global edge network** | Low latency from anywhere in the world |

---

## Part 2: Cloudflare Account Setup

### Step 2.1: Create Cloudflare Account

If you don't have a Cloudflare account:

1. Navigate to [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
2. Enter your email and create a password
3. Verify your email address

### Step 2.2: Add Your Domain to Cloudflare

If your domain isn't already on Cloudflare:

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click **"Add a Site"**
3. Enter your domain name (e.g., `yourdomain.com`)
4. Select the **Free** plan (sufficient for this project)
5. Cloudflare will scan your existing DNS records
6. Review and confirm the DNS records
7. Update your domain's nameservers at your registrar to Cloudflare's nameservers

**Cloudflare Nameservers (example):**
```
ns1.cloudflare.com
ns2.cloudflare.com
```

**Wait for DNS propagation:** This can take up to 24 hours, but usually completes within a few hours.

Verify propagation:
```bash
dig NS yourdomain.com
```

### Step 2.3: Enable Zero Trust

1. In the Cloudflare Dashboard, click **"Zero Trust"** in the left sidebar
2. If this is your first time:
   - Enter a team name (e.g., `kyhomelab`)
   - Select the **Free** plan
   - Complete the onboarding wizard

---

## Part 3: Creating and Configuring the Tunnel

### Step 3.1: Authenticate cloudflared

SSH into your VM and run:

```bash
cloudflared tunnel login
```

**What happens:**
1. A URL is displayed in the terminal
2. Copy and paste this URL into a web browser
3. Select the domain you want to use for the tunnel
4. Click **"Authorize"**

**Terminal output:**
```
Please open the following URL and log in with your Cloudflare account:

https://dash.cloudflare.com/argotunnel?callback=https%3A%2F%2Flogin.cloudflareaccess.org%2F...

Leave cloudflared running to download the cert automatically.
```

After authorization:
```
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
/home/kyhomelab/.cloudflared/cert.pem
```

**Verify the certificate was created:**
```bash
ls -la ~/.cloudflared/
```

**Expected output:**
```
drwx------  2 kyhomelab kyhomelab 4096 Dec 22 12:00 .
drwxr-xr-x 15 kyhomelab kyhomelab 4096 Dec 22 11:00 ..
-rw-------  1 kyhomelab kyhomelab 1876 Dec 22 12:00 cert.pem
```

### Step 3.2: Create the Tunnel

Create a new named tunnel:

```bash
cloudflared tunnel create gemini-cli-tunnel
```

**What this command does:**
- Creates a new tunnel in Cloudflare's infrastructure
- Generates a unique tunnel ID (UUID)
- Creates a credentials file locally

**Output:**
```
Tunnel credentials written to /home/kyhomelab/.cloudflared/abc12345-6789-def0-1234-567890abcdef.json. cloudflared chose this file based on where your origin certificate was found. Keep this file secret. To revoke these credentials, delete the tunnel.

Created tunnel gemini-cli-tunnel with id abc12345-6789-def0-1234-567890abcdef
```

**Important:** Note your tunnel ID (the UUID). You'll need it for configuration.

**List your tunnels:**
```bash
cloudflared tunnel list
```

**Output:**
```
ID                                   NAME                CREATED              CONNECTIONS
abc12345-6789-def0-1234-567890abcdef gemini-cli-tunnel   2024-12-22T12:00:00Z
```

### Step 3.3: Configure DNS Routing

Route your subdomain to the tunnel:

```bash
cloudflared tunnel route dns gemini-cli-tunnel code.yourdomain.com
```

**Replace `code.yourdomain.com` with your actual subdomain.**

**What this command does:**
- Creates a CNAME record in Cloudflare DNS
- Points your subdomain to your tunnel's unique hostname

**Output:**
```
Added CNAME code.yourdomain.com which will route to this tunnel tunnelID=abc12345-6789-def0-1234-567890abcdef
```

**Verify the DNS record was created:**

1. Go to Cloudflare Dashboard → Your domain → DNS
2. Look for a CNAME record for `code` pointing to `abc12345-6789-def0-1234-567890abcdef.cfargotunnel.com`

Or via command line:
```bash
dig CNAME code.yourdomain.com
```

### Step 3.4: Create Tunnel Configuration File

Create the configuration file:

```bash
nano ~/.cloudflared/config.yml
```

Add the following content:

```yaml
# Cloudflare Tunnel Configuration
# ================================
# This file defines how cloudflared routes incoming traffic.

# Tunnel ID (replace with your actual tunnel ID from step 3.2)
tunnel: abc12345-6789-def0-1234-567890abcdef

# Path to the credentials file (replace with your actual tunnel ID)
credentials-file: /home/kyhomelab/.cloudflared/abc12345-6789-def0-1234-567890abcdef.json

# Ingress Rules
# =============
# Ingress rules define how traffic is routed from hostnames to local services.
# Rules are evaluated in order; the first matching rule is used.

ingress:
  # Rule 1: Route code.yourdomain.com to VS Code Server
  # ----------------------------------------------------
  # Hostname: The public URL users will access
  # Service: The local service to forward traffic to
  - hostname: code.yourdomain.com
    service: http://localhost:8080
    # Optional: Origin server configuration
    originRequest:
      # Disable TLS verification for local service (localhost doesn't have a certificate)
      noTLSVerify: true

  # Catch-all Rule (REQUIRED)
  # -------------------------
  # This rule is required. It handles requests that don't match any hostname.
  # Returns a 404 error for unmatched requests.
  - service: http_status:404
```

**Configuration explained:**

| Field | Purpose |
|-------|---------|
| `tunnel` | Your unique tunnel ID |
| `credentials-file` | Path to tunnel credentials JSON |
| `ingress` | List of routing rules |
| `hostname` | Public URL to match |
| `service` | Local service to forward to |
| `originRequest` | Advanced origin settings |

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

### Step 3.5: Validate Configuration

Check for configuration errors:

```bash
cloudflared tunnel ingress validate
```

**Expected output:**
```
Validating rules from /home/kyhomelab/.cloudflared/config.yml
OK
```

If you see errors, check:
- YAML syntax (proper indentation)
- Tunnel ID matches your created tunnel
- Credentials file path is correct

### Step 3.6: Test the Tunnel Manually

Before installing as a service, test that everything works:

```bash
cloudflared tunnel run gemini-cli-tunnel
```

**Expected output:**
```
2024-12-22T12:00:00Z INF Starting tunnel tunnelID=abc12345-6789-def0-1234-567890abcdef
2024-12-22T12:00:00Z INF Version 2024.12.0
2024-12-22T12:00:00Z INF ICMP proxy will use 192.168.1.50 as source for ICMP echo
2024-12-22T12:00:00Z INF Starting metrics server on 127.0.0.1:34567
2024-12-22T12:00:01Z INF Connection established connIndex=0 connection=abc12345 ...
2024-12-22T12:00:01Z INF Connection established connIndex=1 connection=def67890 ...
2024-12-22T12:00:01Z INF Connection established connIndex=2 connection=ghi11111 ...
2024-12-22T12:00:01Z INF Connection established connIndex=3 connection=jkl22222 ...
```

The tunnel creates 4 connections by default for redundancy.

**Test access:**
1. Open a browser (on a different device if possible)
2. Navigate to `https://code.yourdomain.com`
3. You should see the code-server login page (or be prompted for Zero Trust auth if configured)

Press `Ctrl+C` to stop the tunnel.

### Step 3.7: Install as System Service

Install cloudflared as a system service for automatic startup:

```bash
sudo cloudflared service install
```

**What this command does:**
- Copies configuration to `/etc/cloudflared/config.yml`
- Creates a systemd service file
- Enables the service to start at boot

**Start the service:**
```bash
sudo systemctl start cloudflared
```

**Check service status:**
```bash
sudo systemctl status cloudflared
```

**Expected output:**
```
● cloudflared.service - cloudflared
     Loaded: loaded (/etc/systemd/system/cloudflared.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2024-12-22 12:00:00 EST; 5s ago
   Main PID: 12345 (cloudflared)
      Tasks: 7 (limit: 4667)
     Memory: 25.0M
        CPU: 245ms
     CGroup: /system.slice/cloudflared.service
             └─12345 /usr/bin/cloudflared --no-autoupdate tunnel run --token <token>

Dec 22 12:00:00 gemini-cli-vm cloudflared[12345]: Connection established connIndex=0
```

**Verify the tunnel is running:**
```bash
cloudflared tunnel info gemini-cli-tunnel
```

---

## Part 4: Zero Trust Access Policies

Now we'll configure authentication to protect your tunnel.

### Step 4.1: Access Zero Trust Dashboard

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click **"Zero Trust"** in the left sidebar
3. Navigate to **Access** → **Applications**

### Step 4.2: Create Access Application

1. Click **"Add an application"**
2. Select **"Self-hosted"**

### Step 4.3: Configure Application Details

**Application Configuration:**

| Setting | Value | Description |
|---------|-------|-------------|
| Application name | `VS Code Server` | Display name in dashboard |
| Session Duration | `24 hours` | How long before re-authentication |

**Application Domain:**

| Setting | Value |
|---------|-------|
| Subdomain | `code` |
| Domain | `yourdomain.com` |

Full URL: `https://code.yourdomain.com`

**Additional Settings (optional):**
- **Application logo:** Upload a VS Code icon
- **Skip identity provider selection:** Enable if using only one IdP

Click **"Next"** to continue.

### Step 4.4: Configure Access Policies

Create a policy that defines who can access the application.

**Policy Configuration:**

| Setting | Value |
|---------|-------|
| Policy name | `Allow Authorized Users` |
| Action | `Allow` |

**Include Rules:**

Choose one of these authentication methods:

---

**Option A: Email One-Time PIN (Simplest)**

Good for: Personal use, single user

| Selector | Operator | Value |
|----------|----------|-------|
| Emails | In | `your-email@example.com` |

When you access the application:
1. Enter your email address
2. Receive a one-time PIN via email
3. Enter the PIN to authenticate

---

**Option B: Email Domain (Multiple Users)**

Good for: Small team, all users share an email domain

| Selector | Operator | Value |
|----------|----------|-------|
| Emails ending in | -- | `@yourdomain.com` |

---

**Option C: Identity Provider (Most Secure)**

Good for: Production use, MFA enforcement

First, configure an Identity Provider:

1. Go to **Settings** → **Authentication** → **Login methods**
2. Click **"Add new"**
3. Select your IdP (Google, GitHub, Azure AD, etc.)
4. Follow the configuration instructions

Then in your policy:

| Selector | Operator | Value |
|----------|----------|-------|
| Login Methods | -- | `Google` |

---

### Step 4.5: Optional: Add Additional Rules

**Require Specific Country:**
| Selector | Operator | Value |
|----------|----------|-------|
| Country | Is | `United States` |

**Block Specific IPs:**
Create a second policy with:
- Policy name: `Block Bad Actors`
- Action: `Block`
- IP Ranges: List of blocked IPs

Click **"Next"** and then **"Add application"**.

### Step 4.6: Verify Application Created

After creation, you'll see your application in the list:

| Name | Type | URLs |
|------|------|------|
| VS Code Server | Self-hosted | code.yourdomain.com |

---

## Part 5: Testing and Verification

### Step 5.1: Test Authentication Flow

1. Open a **private/incognito browser window**
2. Navigate to `https://code.yourdomain.com`
3. You should see the Cloudflare Access login page

**If using Email OTP:**
- Enter your email address
- Click **"Send me a code"**
- Check your email for the verification code
- Enter the code
- You should be redirected to code-server

### Step 5.2: Verify Access Logs

1. Go to **Zero Trust** → **Logs** → **Access Requests**
2. You should see your login attempt
3. Check the details: IP address, user agent, decision

### Step 5.3: Test from Different Network

If possible, test from a different network (mobile data, coffee shop, etc.):

1. Navigate to `https://code.yourdomain.com`
2. Verify authentication works
3. Verify code-server loads correctly

### Step 5.4: Verify Service Recovery

Test that the tunnel recovers after restart:

```bash
# Stop the service
sudo systemctl stop cloudflared

# Verify site is inaccessible (may take a few seconds)
curl -I https://code.yourdomain.com

# Start the service
sudo systemctl start cloudflared

# Verify site is accessible again
curl -I https://code.yourdomain.com
```

---

## Part 6: Advanced Configuration

### 6.1: Configure Session Settings

In Zero Trust Dashboard → **Settings** → **Authentication** → **Session management**:

| Setting | Recommended Value |
|---------|------------------|
| Global session duration | 24 hours |
| Application session duration | 24 hours |

### 6.2: Enable Logging

View detailed access logs:

1. Go to **Logs** → **Access Requests**
2. Filter by application or user
3. Export logs if needed

### 6.3: Set Up Alerts

Configure alerts for suspicious activity:

1. Go to **Notifications** → **Create**
2. Select alert type:
   - Multiple failed login attempts
   - Access from new country
   - Access outside business hours

### 6.4: Add Additional Services

To add more services to the tunnel, edit the configuration:

```bash
sudo nano /etc/cloudflared/config.yml
```

Add additional ingress rules:

```yaml
ingress:
  # VS Code Server
  - hostname: code.yourdomain.com
    service: http://localhost:8080

  # Additional service example: Portainer
  - hostname: docker.yourdomain.com
    service: http://localhost:9000

  # Catch-all (must be last)
  - service: http_status:404
```

Then:
1. Add DNS route: `cloudflared tunnel route dns gemini-cli-tunnel docker.yourdomain.com`
2. Restart service: `sudo systemctl restart cloudflared`
3. Create Access Application for the new service

### 6.5: Multiple Authentication Factors

For additional security, require multiple factors:

1. Edit your Access policy
2. Add an **AND** rule:
   - **Include:** Email in `your-email@example.com` **AND**
   - **Include:** Country is `United States`

---

## Troubleshooting

### Issue: "Connection refused" Error

**Symptoms:**
- Browser shows "This site can't be reached"
- No error in cloudflared logs

**Check:**
1. Is cloudflared running?
   ```bash
   sudo systemctl status cloudflared
   ```

2. Is code-server running?
   ```bash
   sudo systemctl status code-server@$USER
   ```

3. Is code-server listening on correct port?
   ```bash
   sudo lsof -i :8080
   ```

**Fix:**
```bash
sudo systemctl restart cloudflared
sudo systemctl restart code-server@$USER
```

### Issue: "Bad Gateway" or "502" Error

**Symptoms:**
- Cloudflare page with 502 error
- Tunnel connects but can't reach service

**Check:**
1. Verify service URL in config.yml matches actual service
2. Check code-server is binding to correct address

**Fix:**
Ensure code-server config has:
```yaml
bind-addr: 127.0.0.1:8080
```

### Issue: "Access Denied" at Zero Trust Login

**Symptoms:**
- Can reach login page but access is denied after authentication

**Check:**
1. Is your email in the allow list?
2. Are there conflicting policies?

**Fix:**
1. Go to **Access** → **Applications** → Edit your app
2. Review policy rules
3. Ensure your email/identity matches an allow rule

### Issue: Tunnel Disconnects Frequently

**Symptoms:**
- Tunnel shows "Reconnecting" often
- Connections drop

**Check:**
1. Network stability on VM
2. Cloudflared version (update if old)

**Fix:**
```bash
# Update cloudflared
sudo apt update
sudo apt upgrade -y cloudflared

# Check for network issues
ping -c 5 cloudflare.com
```

### Issue: DNS Not Resolving

**Symptoms:**
- `dig code.yourdomain.com` returns no results
- "DNS_PROBE_FINISHED_NXDOMAIN" in browser

**Check:**
1. DNS record exists in Cloudflare dashboard
2. Domain nameservers are set to Cloudflare

**Fix:**
```bash
# Re-add DNS route
cloudflared tunnel route dns gemini-cli-tunnel code.yourdomain.com
```

### Viewing Logs

**cloudflared logs:**
```bash
# Real-time logs
journalctl -u cloudflared -f

# Last 100 lines
journalctl -u cloudflared -n 100

# Logs since boot
journalctl -u cloudflared -b
```

**code-server logs:**
```bash
journalctl -u code-server@$USER -f
```

---

## Quick Reference

### Useful Commands

| Task | Command |
|------|---------|
| Check tunnel status | `cloudflared tunnel info gemini-cli-tunnel` |
| List tunnels | `cloudflared tunnel list` |
| View tunnel config | `cat ~/.cloudflared/config.yml` |
| Restart tunnel | `sudo systemctl restart cloudflared` |
| View tunnel logs | `journalctl -u cloudflared -f` |
| Validate config | `cloudflared tunnel ingress validate` |

### Important Paths

| File | Location |
|------|----------|
| User tunnel config | `~/.cloudflared/config.yml` |
| System tunnel config | `/etc/cloudflared/config.yml` |
| Tunnel credentials | `~/.cloudflared/<tunnel-id>.json` |
| Auth certificate | `~/.cloudflared/cert.pem` |

### Cloudflare Dashboard Locations

| Task | Path |
|------|------|
| DNS Records | Dashboard → Domain → DNS |
| Zero Trust | Dashboard → Zero Trust |
| Access Apps | Zero Trust → Access → Applications |
| Access Logs | Zero Trust → Logs → Access Requests |
| Tunnel Status | Zero Trust → Networks → Tunnels |

---

## Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Zero Trust Access Documentation](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [cloudflared CLI Reference](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/configuration-file/)
- [Identity Provider Setup Guides](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/)
