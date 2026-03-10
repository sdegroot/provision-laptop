# Codex Instruction: Build a Reproducible Fedora Silverblue Laptop Setup

## Objective

Create a Git repository that automates provisioning and maintenance of a secure, reproducible Fedora Silverblue development laptop environment.

The repository must:

- Install a new machine in a mostly automated way
- Maintain the machine in a desired-state model
- Be testable in virtual machines on macOS and Linux
- Produce a bootable installer USB
- Be secure-by-default
- Keep the host system clean and maintainable
- Store the system definition in Git

The repository should act as Infrastructure-as-Code for a personal developer laptop.

---

# Design Goals

## Reproducibility

The laptop should be installable with minimal manual work.

Example workflow:

Boot installer USB  
→ Kickstart installs Fedora Silverblue  
→ First boot  
→ git clone repo  
→ ./bin/install  
→ machine ready

All configuration should live in Git where possible.

The system should be rebuildable without undocumented steps.

---

# Day-0 Provisioning + Day-2 Desired State

The repository must support both initial provisioning and ongoing reconciliation.

## Day-0 provisioning

Used when installing a new machine:

- Disk partitioning
- LUKS encryption
- Btrfs filesystem
- Fedora Silverblue installation
- User creation
- First-boot configuration

## Day-2 desired state

Used after the machine is running.

Commands must include:

bin/install  
bin/apply  
bin/check  
bin/plan  

Meaning:

install → initial setup  
apply → enforce desired state  
check → verify system matches repo  
plan → show pending changes

The repository must act as a reconciliation engine.

---

# Fedora Silverblue Architecture

Use Fedora Silverblue as the base OS.

Reasons:

- Immutable base system
- Reliable upgrades
- Reduced configuration drift
- Container-friendly development model
- Safer experimentation

The host OS should remain minimal.

Use a layered model:

GUI applications → Flatpak  
Development environments → Toolbox  
Runtime version management → mise  
Sandbox workloads → Podman  

Avoid polluting the host with unnecessary packages.

---

# Security Model

The laptop must be secure by default.

## Disk encryption

Use:

LUKS for full disk encryption  
Btrfs for filesystem management  

## Hardware security

Support:

YubiKey  
1Password  

Secrets must never be stored in Git.

Manual steps should remain for:

- YubiKey enrollment
- 1Password login
- SSH private keys

The repository should document and verify these steps.

---

# Disk Layout

Support two install modes.

## VM mode (single disk)

EFI  
LUKS  
Btrfs subvolumes:

/  
/home  
/var  
/var/lib/containers  

## Laptop mode (two disks)

Disk 1: system

EFI  
LUKS  
Btrfs subvolumes:

/  
/var  
/var/lib/containers  

Disk 2: data

LUKS  
Btrfs subvolumes:

/home  
/work  
/sandbox  

Reasons:

- separation of OS and user data
- easier reinstall of OS
- container storage optimization
- project isolation
- encrypted data protection

---

# Repository Structure

The generated repository should resemble:

repo/
README.md
docs/
kickstart/
bootstrap/
state/
dotfiles/
toolbox/
mise/
containers/
usb/
tests/
bin/

---

# Desired State Definition

Desired system state must live in declarative files:

state/flatpaks.txt  
state/toolbox-profiles.yml  
state/directories.txt  
state/host-packages.txt  

Scripts should reconcile the machine with this state.

---

# Development Environment

Use Toolbox profiles for development stacks.

Examples:

dev-base  
dev-web  
dev-python  
dev-infra  

Runtime versions should be managed using mise.

Projects can include their own mise.toml.

---

# GUI Applications

Install GUI applications using Flatpak.

Examples:

IntelliJ IDEA  
Firefox  
1Password  

Reasons:

- better sandboxing
- compatibility with Silverblue
- avoids host package pollution

---

# Project Isolation

Support three levels:

Basic → mise runtime separation  
Intermediate → Toolbox profiles  
Strong → Podman sandbox containers

AI tools should run in Podman containers with limited mounts.

Never mount the entire home directory by default.

---

# YubiKey Integration

Support:

- SSH hardware keys
- optional LUKS unlock via systemd-cryptenroll

Enrollment should be documented but not fully automated.

Example command:

systemd-cryptenroll --fido2-device=auto /dev/nvme0n1pX

---

# 1Password Integration

Support:

- 1Password desktop app
- 1Password SSH agent
- SSH configuration pointing to agent socket

Secrets must remain outside Git.

---

# USB Installer

The repository must include tooling to create a bootable installer.

Capabilities:

- write Fedora Silverblue ISO to USB
- place Kickstart file on USB
- optionally patch boot configuration

Files:

usb/make-usb.sh  
usb/patch-grub.sh  

---

# VM Testing

The setup must be testable in a VM before deploying to real hardware.

Support instructions for:

Linux hosts  
macOS hosts  

Test workflow:

Create VM  
Attach ISO  
Boot installer  
Run Kickstart install  
Run bootstrap  
Verify state  

Include smoke tests.

---

# Quality Requirements

Scripts should:

- be idempotent
- use clear logging
- fail safely
- avoid destructive actions unless explicit

Avoid hidden assumptions.

---

# Final Outcome

The repository must enable:

Boot USB  
→ automatic OS install  
→ git clone repo  
→ apply configuration  
→ developer workstation ready

The result should be a secure, reproducible, maintainable developer laptop configuration.

