# Auto Initialization Bash Script for Fedora/RHEL-based Systems

## Overview
This script provides an automated setup tool for RedHat-based Linux distributions (Fedora, Rocky Linux, AlmaLinux, Oracle Linux). It handles everything from system initialization to development tools, GUI applications, and other useful software in a single execution.

## Prerequisites
- Root privileges
- One of the following Linux distributions:
  - Fedora
  - Rocky Linux
  - AlmaLinux
  - Oracle Linux
- Active internet connection

## Key Features
- Optimizes system package manager (DNF)
- Changes repositories to domestic mirrors
- Adds RPM Fusion and EPEL repositories
- Installs essential development tools
- Installs system management utilities
- Optional GUI application installation
- Flatpak setup and application installation

## Main Packages Installed

### Core Packages
- gcc, gdb (development tools)
- fish (modern shell)
- neovim, vim, helix (text editors)
- tmux, byobu (terminal multiplexers)
- htop, btop (system monitors)
- fastfetch, neofetch (system information tools)
- ranger (file manager)
- hardinfo2 (hardware information)

### Server Management Tools (Rocky Linux/AlmaLinux/Oracle Linux)
- Cockpit-related packages
  - Web-based system management
  - Default port: 9090

### Optional Packages
- GUI applications: putty, remmina, bleachbit
- Flatpak applications: PeaZip, rnote

## Usage Instructions

1. Download the script:
```bash
wget https://[script_URL]/R_INSTALL.sh
```

2. Make it executable:
```bash
chmod +x R_INSTALL.sh
```

3. Run with root privileges:
```bash
sudo ./R_INSTALL.sh
```

## Interactive Installation Options
- Install GUI packages (Y/N)
- Install Flatpak and tools (Y/N)

## System Configuration Changes
- Default locale: en_US.UTF-8
- DNF optimizations:
  - Fastest mirror selection
  - Parallel downloads enabled
  - Cache preservation
  - Default "Yes" for installations

## Important Notes
- Internet connection required during installation
- System updates and package installations may take time
- Some features may not be available on all distributions
- System backup is recommended before installation

## Troubleshooting
Errors will display:
- Line number where error occurred
- Command being executed

If issues persist, verify:
1. Script is running with root privileges
2. Internet connection is stable
3. System is a supported distribution
