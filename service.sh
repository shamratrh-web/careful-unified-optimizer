#!/system/bin/sh
# Careful Unified Optimizer v6.6 Balanced ThermalGuard & Smoothness service.

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

(
    sleep 35
    for pkg in com.google.android.youtube com.instagram.android com.facebook.katana com.facebook.orca; do
        if pm list packages | grep -q "^package:$pkg$"; then
            cmd package compile -m speed-profile "$pkg" >/dev/null 2>&1
        fi
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

log -t "$LOG_TAG" "v6.6 Balanced ThermalGuard service started"
exit 0
