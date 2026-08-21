#!/system/bin/sh
# Careful Unified Optimizer v6.7 Native C++ Speed & Fluidity service.

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

sleep 15

cleanup_rogue_wpa_supplicant
apply_storage_tuning
apply_display_tuning

if [ -f "$MODDIR/smart_balance.sh" ]; then
    sh "$MODDIR/smart_balance.sh" boot >/dev/null 2>&1
fi

# 1. Immediate priority compilation for core frameworks and daily apps
(
    sleep 25
    for pkg in \
        com.android.systemui \
        com.android.launcher \
        com.android.settings \
        com.google.android.gms \
        com.android.vending \
        com.android.chrome \
        com.google.android.youtube \
        com.instagram.android \
        com.facebook.katana \
        com.facebook.orca
    do
        if pm list packages | grep -q "^package:$pkg$"; then
            cmd package compile -m speed-profile "$pkg" >/dev/null 2>&1
        fi
    done

    # 2. Universal background compiler: compiles ALL installed 3rd-party user apps to native AArch64 machine code
    sleep 60
    pm list packages -3 2>/dev/null | cut -d: -f2 | while read -r user_pkg; do
        [ -z "$user_pkg" ] && continue
        # Check if already compiled to avoid redundant CPU load
        status="$(dumpsys package dexopt 2>/dev/null | grep -A 3 "\[$user_pkg\]" | grep "status=")"
        case "$status" in
            *speed*|*everything*) ;;
            *)
                # Compile in low-power nice mode to protect battery
                nice -n 19 cmd package compile -m speed-profile "$user_pkg" >/dev/null 2>&1
                sleep 2
                ;;
        esac
    done
) &

(
    while true; do
        if [ -f "$MODDIR/smart_balance.sh" ]; then
            sh "$MODDIR/smart_balance.sh" auto >/dev/null 2>&1
        fi
        sleep "$(choose_monitor_interval)"
    done
) &

if [ "$(getprop persist.careful.allow_termux_wpa)" != "1" ]; then
    (
        while true; do
            sleep 300
            cleanup_rogue_wpa_supplicant
        done
    ) &
fi

log -t "$LOG_TAG" "v6.7 Native C++ Speed & Fluidity service started"
exit 0

