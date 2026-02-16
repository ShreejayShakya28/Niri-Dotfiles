#!/bin/bash
# Simple power menu using fuzzel

options="Lock\nLogout\nSuspend\nReboot\nShutdown"

chosen=$(echo -e "$options" | fuzzel --dmenu --prompt "Power: ")

case "$chosen" in
    Lock)
        # Replace with your lock command (e.g., swaylock, hyprlock, etc.)
        swaylock
        ;;
    Logout)
        niri msg action quit
        ;;
    Suspend)
        systemctl suspend
        ;;
    Reboot)
        systemctl reboot
        ;;
    Shutdown)
        systemctl poweroff
        ;;
esac
