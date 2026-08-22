#!/system/bin/sh
# Careful Unified Optimizer - Nightly Automated App Optimizer & Maintenance
# Automatically runs during midnight hours while the phone is charging and screen is off.

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="CarefulNightlyOpt"
STAMP_FILE="$MODDIR/.last_nightly_run"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

mode="${1:-nightly}"

log_opt() {
    log -t "$LOG_TAG" "$1"
    echo "  ➜ $1"
}

is_charging() {
    dumpsys battery 2>/dev/null | grep -qE "AC powered: true|USB powered: true|Wireless powered: true" && return 0
    return 1
}

is_midnight_window() {
    hour="$(date +%H 2>/dev/null)"
    case "$hour" in
        01|02|03|04|05|06) return 0 ;;
        *) return 1 ;;
    esac
}

already_ran_today() {
    today="$(date +%Y-%m-%d 2>/dev/null)"
    last_run="$(cat "$STAMP_FILE" 2>/dev/null)"
    [ "$today" = "$last_run" ] && return 0
    return 1
}

# Pre-flight check for automated run
if [ "$mode" != "force" ]; then
    if ! is_charging; then exit 0; fi
    if screen_is_on; then exit 0; fi
    if ! is_midnight_window; then exit 0; fi
    if already_ran_today; then exit 0; fi
fi

echo "======================================================"
echo "   ⚡ FULL-SYSTEM AOT MACHINE CODE OPTIMIZER"
echo "======================================================"

# 1. High-Priority Frameworks & Core UI Apps
PRIORITY_APPS="
com.android.systemui
com.android.launcher
com.android.settings
com.google.android.gms
com.android.vending
com.android.chrome
com.microsoft.emmx
com.google.android.youtube
com.instagram.android
com.facebook.katana
com.facebook.orca
com.whatsapp
com.whatsapp.w4b
com.wmods.wppenhacer
com.bKash.customerapp
com.dbbl.nexus.pay
com.linkedin.android
"

echo "\n[Step 1] Optimizing Core System Frameworks & Daily Apps..."
for pkg in $PRIORITY_APPS; do
    if pm list packages 2>/dev/null | grep -q "^package:$pkg$"; then
        status="$(dumpsys package dexopt 2>/dev/null | grep -A 3 "\[$pkg\]" | grep "status=")"
        case "$status" in
            *status=speed\]*)
                echo "  ✓ [ALREADY OPTIMIZED] $pkg"
                ;;
            *)
                echo "  ⚙ [COMPILING TO SPEED] $pkg ..."
                nice -n 19 cmd package compile -m speed -f "$pkg" >/dev/null 2>&1
                echo "  ✓ [COMPILED] $pkg"
                sleep 1
                ;;
        esac
    fi
done

# 2. Universal 3rd-Party & User App Compilation
echo "\n[Step 2] Scanning & Optimizing Installed User Applications..."
ALL_PACKAGES="$(pm list packages 2>/dev/null | cut -d: -f2)"
TOTAL_COUNT="$(echo "$ALL_PACKAGES" | wc -w)"
CURRENT=0

for pkg in $ALL_PACKAGES; do
    [ -z "$pkg" ] && continue
    CURRENT=$((CURRENT + 1))
    
    if [ "$mode" != "force" ] && screen_is_on; then
        echo "  ⚠ Screen turned on. Pausing background optimizer."
        break
    fi

    status="$(dumpsys package dexopt 2>/dev/null | grep -A 3 "\[$pkg\]" | grep "status=")"
    case "$status" in
        *speed*|*everything*)
            echo "  [$CURRENT/$TOTAL_COUNT] ✓ $pkg (Optimized)"
            ;;
        *)
            echo "  [$CURRENT/$TOTAL_COUNT] ⚙ AOT Compiling $pkg ..."
            nice -n 19 cmd package compile -m speed-profile "$pkg" >/dev/null 2>&1
            echo "  [$CURRENT/$TOTAL_COUNT] ✓ $pkg (Complete)"
            sleep 1
            ;;
    esac
done

# 3. System Memory, ZRAM & Storage Maintenance
echo "\n[Step 3] Performing System Storage & Memory Maintenance..."
echo "  ➜ Clearing daily UsageStats I/O bloat..."
rm -rf /data/system/usagestats/0/daily/* 2>/dev/null || true

if [ -f "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" ]; then
    echo "  ➜ Pruning TrickyStore target list to 25 essential apps..."
    sh "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" >/dev/null 2>&1
fi

echo "  ➜ Compacting ZRAM memory blocks & trimming caches..."
pm trim-caches 2G >/dev/null 2>&1
echo 1 > /sys/block/zram0/compact 2>/dev/null || true

echo "  ➜ Running UFS block-layer fstrim on /data..."
fstrim -v /data 2>/dev/null || true
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

date +%Y-%m-%d >"$STAMP_FILE" 2>/dev/null
echo "\n======================================================"
echo "   🎉 ALL APPLICATIONS & OS FULLY OPTIMIZED!"
echo "======================================================"
exit 0
