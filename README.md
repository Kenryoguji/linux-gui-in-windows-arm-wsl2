# Linux GUI in Windows on ARM (WSL2)

A full XFCE desktop running inside WSL2 on a Windows on ARM machine, accessed from Windows through RDP.

## Constraints

This setup exists because of a specific limitation, not by preference. The target machine runs Windows 11 on ARM. On that architecture, common desktop virtualization software (VirtualBox, VMware) does not reliably support ARM hosts, and ARM-aware alternatives such as UTM were not usable here either. WSL2 is the one Linux environment officially supported by Microsoft on Windows on ARM, but on its own it only provides WSLg, which forwards individual Linux GUI applications into the Windows desktop rather than a full, independent desktop session.

The goal was a complete, self-contained Linux desktop — its own window manager, taskbar, icons — displayed in a normal window, without relying on a VM.

## Environment

- Distribution: Ubuntu 24.04 (WSL2, ARM64)
- Host: Windows 11 on ARM

## Approach

The desktop is provided by XFCE. xrdp acts as the RDP server, listening for incoming connections and starting a graphical session on request; xorgxrdp lets it create a virtual X server for that session. Any standard RDP client can then connect to it like a remote machine.

## What was configured

XFCE and xrdp were installed, with the default screen locker removed for incompatibility with WSL's environment. systemd was enabled inside WSL, since xrdp runs as a systemd-managed service and WSL2 does not enable systemd by default. The RDP port was changed from its default to avoid a conflict with the Windows host. The session startup script that xrdp runs on each connection was rewritten to resolve a display-environment conflict with WSLg and to correctly initialize the session's internal communication bus.

## Issues resolved

- Session terminating immediately on connection, traced to an error in the startup script.
- Persistent black screen caused by the default screen locker's incompatibility with WSL.
- Stale sessions not being cleared between connection attempts, causing reconnections to reuse a broken state.
- Display conflicts between WSLg's default display server and the X11 session created for RDP.
- The default XFCE startup wrapper refusing to run because it detected an X server already active — expected under xrdp, but not handled by the wrapper.
- Silent failure caused by a missing session communication bus after simplifying the startup script.

## Repository contents

Currently this README only. Configuration files and scripts referenced above will be added to the repository and listed here as they're included.
