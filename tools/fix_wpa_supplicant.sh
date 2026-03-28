#!/system/bin/sh
# Remove rogue Termux-launched wpa_supplicant processes that interfere with the
# vendor-managed Wi-Fi stack on wlan0.

LOG_TAG="CarefulUnifiedOpt"
TOOLSDIR="${0%/*}"
MODDIR="${TOOLSDIR%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

if [ "${QUIET:-0}" != "1" ]; then
    printf "Before:\n"
    list_wpa_supplicant
fi

cleanup_rogue_wpa_supplicant

if [ "${QUIET:-0}" != "1" ]; then
    printf "\nAfter:\n"
    list_wpa_supplicant
fi
