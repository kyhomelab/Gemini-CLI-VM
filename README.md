# Project: Remotely Accessible & Personalized Gemini CLI

## Project Goal

The primary goal of this project is to create a secure, remotely accessible, and personalized Gemini CLI environment. This will serve as a dedicated assistant for tasks such as portfolio building, technical write-ups, and research. The environment will be isolated in a virtual machine to ensure it doesn't interfere with other systems and can be accessed from any location.

## High-Level Design

**Hosting Platform:** The project is hosted on a Proxmox virtual machine within a personal homelab.

**Remote Access & Workflow:**
*   **Primary Access:** A secure Cloudflare Tunnel provides web-based access to a VS Code Server instance.
*   **Development Environment:** `VS Code Server` provides a full-featured development environment in the browser.
*   **Backup Access:** A Tailscale VPN allows for direct, secure access for maintenance.
*   **Data Storage:** All data is stored locally on the VM, ensuring user control.

## Security Considerations

This project is designed with a security-first mindset, incorporating several layers of protection:

*   **Zero Trust Architecture:** Cloudflare Access ensures every connection is authenticated.
*   **Attack Surface Reduction:** A Cloudflare Tunnel exposes the service without opening inbound firewall ports.
*   **Defense in Depth:** Multiple security layers include Cloudflare Access, Tailscale, a VM-level firewall, and Proxmox isolation.
*   **Least Privilege:** Services run under a non-root user.
*   **Secure Authentication:** SSH keys are used for `git` and an Identity Provider (IdP) with MFA is used for web access.
*   **Patch Management:** The plan includes regular OS and software updates.
