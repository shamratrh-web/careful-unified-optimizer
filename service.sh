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

# 0. Prune TrickyStore targets to essential integrity targets to prevent KeyStore IPC lag
if [ -f "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" ]; then
    sh "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" >/dev/null 2>&1
fi

# 0b. Prune bloated UsageStats proto logs to eliminate 15-second android.io unlock hangs
rm -rf /data/system/usagestats/0/daily/* 2>/dev/null || true

# 0c. Trim caches, compact ZRAM, and perform storage fstrim
pm trim-caches 2G >/dev/null 2>&1
echo 1 > /sys/block/zram0/compact 2>/dev/null || true
fstrim -v /data >/dev/null 2>&1

if [ -f "$MODDIR/smart_balance.sh" ]; then
    sh "$MODDIR/smart_balance.sh" boot >/dev/null 2>&1
fi

# 1. Immediate priority compilation for core frameworks, hook modules, and daily apps
(
    sleep 20
    for pkg in \
        com.android.systemui \
        com.android.launcher \
        com.android.settings \
        com.wmods.wppenhacer \
        com.bKash.customerapp \
        com.dbbl.nexus.pay \
        com.linkedin.android \
        com.google.android.gms \
        com.android.vending \
        com.android.chrome \
        com.google.android.youtube \
        com.instagram.android \
        com.facebook.katana \
        com.facebook.orca
    do
        if pm list packages 2>/dev/null | grep -q "^package:$pkg$"; then
            cmd package compile -m speed "$pkg" >/dev/null 2>&1
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

log -t "$LOG_TAG" "v6.8 Ultimate Fluidity & KernelGuard service started"
exit 0

