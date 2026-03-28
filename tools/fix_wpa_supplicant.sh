#!/system/bin/sh
# Remove rogue Termux-launched wpa_supplicant processes that interfere with the
# vendor-managed Wi-Fi stack on wlan0.

LOG_TAG="CarefulUnifiedOpt"

printf "Before:\n"
ps -A -o PID,PPID,USER,NAME,ARGS 2>/dev/null | grep wpa_supplicant | grep -v grep

for proc in /proc/[0-9]*; do
    [ -r "$proc/cmdline" ] || continue
    pid="${proc#/proc/}"
    cmdline="$(tr '\000' ' ' <"$proc/cmdline" 2>/dev/null)"

    case "$cmdline" in
        *"/vendor/bin/hw/wpa_supplicant"*) continue ;;
        *"wpa_supplicant"*"/data/data/com.termux/files/usr/tmp/"*)
            log -t "$LOG_TAG" "Manual cleanup killed rogue wpa_supplicant pid=$pid"
            kill "$pid" 2>/dev/null
            sleep 1
            kill -9 "$pid" 2>/dev/null
            ;;
    esac
done

printf "\nAfter:\n"
ps -A -o PID,PPID,USER,NAME,ARGS 2>/dev/null | grep wpa_supplicant | grep -v grep
