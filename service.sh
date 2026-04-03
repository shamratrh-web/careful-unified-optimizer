#!/system/bin/sh
# Careful Unified Optimizer v6.5 Balanced ThermalGuard service.

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

sleep 20

cleanup_rogue_wpa_supplicant
apply_storage_tuning

if [ -f "$MODDIR/smart_balance.sh" ]; then
    sh "$MODDIR/smart_balance.sh" boot >/dev/null 2>&1
fi

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

log -t "$LOG_TAG" "v6.5 Balanced ThermalGuard service started"
exit 0
