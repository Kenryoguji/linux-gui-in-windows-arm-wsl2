# Linux GUI in Windows on ARM (WSL2)

A full XFCE desktop running inside WSL2 on a Windows on ARM machine, accessed from Windows through RDP.

## Constraints

This setup exists because of a specific limitation, not by preference. The target machine runs **Windows 11 on ARM**. On that architecture:

- Common desktop virtualization software (VirtualBox, VMware) does not support ARM hosts, or only partially, with no reliable way to run a standard x86_64/ARM64 Ubuntu VM.
- UTM and other ARM-aware hypervisors introduce their own overhead and compatibility issues, and were not usable in this case.
- WSL2 is the one Linux environment officially supported and maintained by Microsoft on Windows on ARM, but it only ships with **WSLg**, which forwards individual Linux GUI applications into the Windows desktop — it does not provide a full, independent Linux desktop session.

The goal was to get a complete, self-contained Linux desktop (its own window manager, taskbar, icons) displayed in a normal window, without relying on a VM. The approach: install a desktop environment inside WSL2 and expose it over RDP, so any standard RDP client can connect to it like a remote machine.

## Environment

- Distribution: Ubuntu 24.04 (WSL2, ARM64)
- WSL instance name: `Darma`
- Host: Windows 11 on ARM
- Linux user: `axelt`

## Components

- **XFCE** — the desktop environment (window manager, panel, icons).
- **xrdp** — the RDP server: listens for incoming RDP connections and starts a graphical session on demand.
- **xorgxrdp** — the module that lets xrdp spin up a virtual X server (Xorg) for each session.

---

## 1. Package installation

```bash
sudo apt-get update
sudo apt install xfce4 xfce4-goodies xrdp -y
```

- `xfce4`: the XFCE desktop environment itself.
- `xfce4-goodies`: additional XFCE applications and panel plugins. Not required, but commonly bundled with it.
- `xrdp`: the RDP server that accepts incoming connections and opens a graphical session.
- `-y`: auto-confirms all `apt` prompts.

If the install hits 404 errors (temporary desync on the ARM64 mirrors), rerun with:
```bash
sudo apt-get update
sudo apt install xfce4 xfce4-goodies xrdp -y --fix-missing
```

### Removed package: `light-locker`

`light-locker` (XFCE's screen locker) was removed. It fails under WSL's restricted `/proc`, which caused the session to go to a black screen on startup:

```bash
sudo apt remove --purge light-locker -y
```

---

## 2. Enabling systemd in WSL

`xrdp` installs as a `systemd`-managed service, but `systemd` is not active by default in WSL2.

`/etc/wsl.conf`:
```ini
[boot]
systemd=true
```

- `[boot]`: configuration section applied when the WSL instance starts.
- `systemd=true`: tells WSL to start `systemd` (the standard Linux service manager) on boot.

For this to take effect, the WSL instance has to be fully restarted **from PowerShell, on the Windows side**:
```powershell
wsl --shutdown
```
Then reopen the WSL terminal.

---

## 3. RDP port

The default RDP port (3389) was already in use on the Windows host, so it was changed to **3390**.

`/etc/xrdp/xrdp.ini`, `[Globals]` section:
```ini
port=3390
```

Restart the service to apply it:
```bash
sudo systemctl restart xrdp
```

Check it is listening on the new port:
```bash
sudo ss -tlnp | grep 3390
```
- `ss`: lists active network sockets (modern replacement for `netstat`).
- `-t`: TCP connections only.
- `-l`: listening sockets only.
- `-n`: show ports as numbers instead of resolving service names.
- `-p`: show the process name/PID behind each socket.

---

## 4. Session startup script: `/etc/xrdp/startwm.sh`

This is the script `xrdp-sesman` (xrdp's session manager) runs to start the desktop on every new connection.

### Final content

```sh
#!/bin/sh
exec > ~/.startwm-debug.log 2>&1
set -x

if test -r /etc/profile; then
        . /etc/profile
fi

if test -r ~/.profile; then
        . ~/.profile
fi

export GDK_BACKEND=x11
unset WAYLAND_DISPLAY

exec dbus-launch --exit-with-session /usr/bin/xfce4-session
```

Applied with:
```bash
sudo tee /etc/xrdp/startwm.sh > /dev/null << 'EOF'
[... content above ...]
EOF
```
(`tee` writes its input to the given file; `> /dev/null` suppresses the redundant echo to the terminal; the `<< 'EOF' ... EOF` block is a heredoc, used to pass multiple lines of text at once without opening an editor.)

### Line-by-line

- `#!/bin/sh`: run this script with the `sh` interpreter.
- `exec > ~/.startwm-debug.log 2>&1`: redirect all of the script's output (stdout and stderr) to `~/.startwm-debug.log`, for debugging.
- `set -x`: trace mode — each command is printed (prefixed with `+`) before it runs.
- `if test -r /etc/profile; then . /etc/profile; fi`: if `/etc/profile` exists and is readable, source it (load its variables into the current shell).
- Same for `~/.profile`, the user-specific version.
- `export GDK_BACKEND=x11`: forces GTK-based applications (XFCE included) to use X11 instead of Wayland. Required because WSLg defaults to Wayland, which conflicts with the X11 session xrdp creates.
- `unset WAYLAND_DISPLAY`: clears the `WAYLAND_DISPLAY` variable inherited from WSLg, which otherwise points to the wrong display.
- `exec dbus-launch --exit-with-session /usr/bin/xfce4-session`: starts the XFCE session inside a freshly created D-Bus environment (see below), replacing the script's own process.

### Why `dbus-launch` is required

Bypassing the standard `/etc/X11/Xsession` script (which normally handles starting D-Bus) also removes the **D-Bus session bus** — the internal communication system XFCE's components (window manager, panel, settings daemon) depend on. Without it, `xfce4-session` starts but stalls silently, which showed up as a persistent black screen with no visible error.

`dbus-launch --exit-with-session /usr/bin/xfce4-session` creates the missing D-Bus bus, starts `xfce4-session` inside it, and shuts the bus down cleanly when the session ends (`--exit-with-session`).

---

## 5. Restarting services before reconnecting

During setup, a stale xrdp session sometimes remained active between attempts, causing xrdp to reuse a broken session instead of starting fresh:

```bash
sudo systemctl restart xrdp-sesman
sudo systemctl restart xrdp
```

- `xrdp-sesman`: xrdp's session manager, responsible for creating/destroying graphical sessions.
- `xrdp`: the RDP server itself, accepting incoming connections.

Not required on a day-to-day basis once the setup is stable, but useful after any change to `startwm.sh`.

---

## 6. Connecting from Windows

1. Open **Remote Desktop Connection** (`mstsc`) on Windows.
2. Connect to `localhost:3390`.
3. A certificate warning appears (xrdp's self-signed certificate) — expected for a local connection, safe to accept.
4. On the xrdp login screen: select the **Xorg** session, enter the Linux username and password.

---

## 7. Issues encountered

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | Session closes immediately, exit code 127 | Wrong binary name referenced in `~/.xsession` | File corrected, later made irrelevant once `startwm.sh` stopped reading it |
| 2 | Persistent black screen | `light-locker` incompatible with WSL's `/proc` | `sudo apt remove --purge light-locker -y` |
| 3 | Black screen despite previous fixes | Stale session never actually torn down between attempts | Restart `xrdp-sesman` and `xrdp` before each connection attempt |
| 4 | `cannot open display: wayland-0` errors (xfwm4, panel, ...) | `WAYLAND_DISPLAY`, inherited from WSLg via `/etc/profile` / `~/.profile`, leaking into the session | `export GDK_BACKEND=x11` and `unset WAYLAND_DISPLAY` in `startwm.sh` |
| 5 | Window manager exits instantly, no visible error | `startxfce4` refuses to start because it detects an X server already running on the display (always true under xrdp) | Replaced `exec startxfce4` with `exec /usr/bin/xfce4-session` (direct call, bypassing the wrapper script) |
| 6 | Screen still black, nothing in the logs | Loss of the D-Bus session bus after bypassing `/etc/X11/Xsession` | Added `dbus-launch --exit-with-session` in front of `xfce4-session` |

---

## 8. Diagnostic files

- `~/.startwm-debug.log`: full trace of `startwm.sh`'s execution (via `set -x` and the output redirection set up in the script). First file to check for any new issue.
- `/var/log/xrdp-sesman.log`: session lifecycle log (start, stop, exit codes):
  ```bash
  sudo tail -50 /var/log/xrdp-sesman.log
  ```
- `~/.xorgxrdp.<N>.log`: the virtual X server log for display number `<N>` (e.g. `~/.xorgxrdp.11.log`).

## 9. Deprecated file

`~/.xsession` was created early in the process but is no longer used: `startwm.sh` no longer goes through `/etc/X11/Xsession`, which was the only mechanism reading it. Safe to remove (`rm ~/.xsession`) or leave in place — it has no effect either way.

---

## Repository contents

Currently this repository contains this README only. Additional resources (scripts, config file templates) will be added and documented here as they are included.
