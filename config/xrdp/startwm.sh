#!/bin/sh
# /etc/xrdp/startwm.sh
# Run by xrdp-sesman to start the desktop session on each RDP connection.

# Logs every step below — needed to catch failures that leave no visible error.
exec > ~/.startwm-debug.log 2>&1
set -x

# If /etc/profile exists and is readable...
if test -r /etc/profile; then
        . /etc/profile

	# ...load it: system-wide environment variables (PATH, locale, etc.).
fi

# If ~/.profile exists and is readable...
if test -r ~/.profile; then
        . ~/.profile
	# ...load it too: per-user environment overrides.
fi

# --- Modification #1: work around WSLg ---
# WSLg defaults GTK apps to Wayland and sets WAYLAND_DISPLAY. That variable
# leaks into this session via /etc/profile and ~/.profile (loaded above),
# and conflicts with the separate X11 session xrdp creates for RDP.
# Added these two lines to force X11 and clear the conflicting variable.

export GDK_BACKEND=x11
unset WAYLAND_DISPLAY

# --- Modification #2: bypasses the default /etc/X11/Xsession ---
# The stock startwm.sh ends with `exec /etc/X11/Xsession`, which also starts
# D-Bus along the way. Replacing it with a direct xfce4-session call (below)
# means D-Bus is no longer started automatically — so it has to be started
# explicitly here with dbus-launch, or XFCE's components (window manager,
# panel) hang silently: a black screen, no error.

exec dbus-launch --exit-with-session /usr/bin/xfce4-session