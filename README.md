# virtuOSo

**Your homelab VM manager, simplified.**

virtuOSo is a KVM-based homelab appliance delivered as an ISO install. Launch and manage Linux virtual machines from a browser, and connect AI assistants like Claude Code or Codex through a built-in MCP server to automate and control infrastructure.

**Project Website:**  
https://rickjacobo.com/virtuoso.html

## Features

- **Web Dashboard** — Launch, monitor, and manage VMs from any browser
- **Web Shell & Console** — SSH, serial, and VNC access directly in the browser
- **Multi-Distro** — Ubuntu, Fedora, and Amazon Linux cloud images
- **Stacks** — Deploy multi-VM environments from declarative YAML templates
- **REST API** — 24+ JSON endpoints for full programmatic control
- **Terraform Provider** — Infrastructure-as-code VM management
- **AI Assistant** — Built-in Claude integration with MCP tool access
- **CLI** — Full command-line interface for scripting and automation
- **Multi-User** — Role-based access control with admin and user roles
- **Custom ISO** — One-step bare metal install on any x86_64 machine

## Install

[Download the latest ISO](http://releases.rickjacobo.dev/virtuoso.iso), write it to a USB drive, and boot your server:

```bash
curl -LO http://releases.rickjacobo.dev/virtuoso.iso
sudo dd if=virtuoso.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

After installation, the web UI is available at `https://<server-ip>`.

## Upgrade

From a running virtuOSo server:

```bash
vm upgrade
```

Or via script:

```bash
curl -sSL https://raw.githubusercontent.com/rickjacobo/virtuoso-releases/main/upgrade.sh | bash
```

## Requirements

- x86_64 machine with Intel VT-x or AMD-V (for KVM)
- 4 GB+ RAM recommended (host + VMs)
