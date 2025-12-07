# Gemini CLI VM: Detailed Implementation Plan

This document provides a detailed, step-by-step plan for implementing the remotely accessible Gemini CLI environment.

## Phase 1: VM Provisioning & OS Setup

#### 1.1 Create Virtual Machine in Proxmox
*   **Allocate Resources:** 2 vCPU, 4 GB RAM, 50 GB storage.
*   **Network Configuration:** Assign a static IP address.

#### 1.2 Choose and Install Linux Distribution
*   **Distribution Choice:** Ubuntu Server LTS.
*   **Installation:** Perform a minimal server installation.

#### 1.3 Initial OS Configuration
*   **System Updates:** Update all installed packages.
*   **User Management:** Create a dedicated non-root user.
*   **SSH Access:** Configure key-based SSH authentication.
*   **Firewall (UFW):** Configure basic firewall rules.

## Phase 2: Core Software Installation

*This phase is executed on the Ubuntu Server VM.*

#### 2.1 Install Gemini CLI
*   Follow the official installation instructions.

#### 2.2 Install Git
*   `sudo apt install git`

#### 2.3 Install VS Code Server
*   Install `code-server` and configure it to run as a `systemd` service.

#### 2.4 Install Cloudflared
*   Install the `cloudflared` daemon from Cloudflare.

## Phase 3: Networking & Access Configuration

#### 3.1 Configure Tailscale (Backup Access)
*   Install and authenticate Tailscale on the VM.

#### 3.2 Configure Cloudflare Tunnel (Primary Access)
*   Create a Cloudflare Tunnel and configure `cloudflared` on the VM to connect to it.
*   Map a public hostname to the local VS Code Server instance.

#### 3.3 Implement Cloudflare Access Policy
*   Create a Cloudflare Access Application and policy to protect the public hostname, requiring authentication via an Identity Provider.

## Phase 4: Project & Git Setup

#### 4.1 Configure Git
*   Set your global Git user name and email.
*   Generate a new SSH key and add it to your GitHub account.

#### 4.2 Create Project Directory Structure
*   Establish a logical directory structure for your projects.

#### 4.3 Clone Portfolio Repository
*   Clone your primary GitHub portfolio repository.

#### 4.4 Transfer Existing Documentation
*   Move existing documentation into the repository, commit, and push the changes.

## Phase 5: Testing & Documentation

#### 5.1 End-to-End Workflow Testing
*   Test both the primary (Cloudflare) and backup (Tailscale) access methods.
*   Verify that you can authenticate, access the environment, use the Gemini CLI, and push changes to GitHub.

#### 5.2 Finalize Project Documentation
*   Review all documentation to ensure it is accurate and complete.
*   Create a summary `README.md` for the GitHub repository.
