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

## Usage

WSL2 does not start on an incoming RDP connection by itself — it only wakes up for specific triggers, such as opening a WSL terminal or running `wsl`. Starting the desktop is therefore a short, ordered sequence:

1. Start the WSL2 instance: open a terminal and run `wsl` (or launch the distro from the Start menu). This boots the instance and, with it, systemd and xrdp.
2. From a separate Windows prompt — `mstsc` doesn't exist inside the Linux shell, so this can't be the same window as step 1 — open Remote Desktop Connection: run `mstsc`, or find it in the Start menu.
3. Enter `localhost:3390` as the address and connect.
4. Accept the self-signed certificate warning (expected for a local xrdp connection).
5. On the xrdp login screen, select the **Xorg** session and enter the Linux username and password.

Passing the address as an argument (`mstsc /v:localhost:3390`) is possible but has proven unreliable from PowerShell; running `mstsc` bare and entering the address in the dialog (step 3) is the more consistent path.

## Repository contents

```
config/
├── wsl.conf           /etc/wsl.conf — enables systemd
└── xrdp/
    ├── startwm.sh      /etc/xrdp/startwm.sh — session startup script
    └── xrdp.ini        /etc/xrdp/xrdp.ini — RDP port (excerpt)
assets/
└── images/
    ├── remote-office.png   Remote Desktop Connection dialog
    └── xfce-desktop.png    The resulting XFCE desktop, over RDP
```

![XFCE desktop running over RDP](assets/images/xfce-desktop.png)
