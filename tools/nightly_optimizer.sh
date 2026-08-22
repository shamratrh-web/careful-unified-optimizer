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
    echo "[$LOG_TAG] $1"
}

is_charging() {
    dumpsys battery 2>/dev/null | grep -qE "AC powered: true|USB powered: true|Wireless powered: true" && return 0
    return 1
}

is_midnight_window() {
    hour="$(date +%H 2>/dev/null)"
    # Window between 01:00 AM and 06:00 AM
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
    if ! is_charging; then
        exit 0
    fi
    if screen_is_on; then
        exit 0
    fi
    if ! is_midnight_window; then
        exit 0
    fi
    if already_ran_today; then
        exit 0
    fi
fi

log_opt "Starting full automated system & app optimization maintenance..."

# 1. High-Priority Frameworks & Core UI Apps (Compile to full native 'speed' mode)
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

for pkg in $PRIORITY_APPS; do
    if pm list packages 2>/dev/null | grep -q "^package:$pkg$"; then
        status="$(dumpsys package dexopt 2>/dev/null | grep -A 3 "\[$pkg\]" | grep "status=")"
        case "$status" in
            *status=speed\]*) ;;
            *)
                log_opt "Compiling priority app to speed: $pkg"
                nice -n 19 cmd package compile -m speed -f "$pkg" >/dev/null 2>&1
                sleep 1
                ;;
        esac
    fi
done

# 2. Universal 3rd-Party & User App Compilation
log_opt "Scanning all installed applications for unoptimized bytecode..."
pm list packages 2>/dev/null | cut -d: -f2 | while read -r pkg; do
    [ -z "$pkg" ] && continue
    
    # Abort if user wakes up device during automated background run
    if [ "$mode" != "force" ] && screen_is_on; then
        log_opt "Screen turned on. Pausing optimization until next idle sleep window."
        break
    fi

    status="$(dumpsys package dexopt 2>/dev/null | grep -A 3 "\[$pkg\]" | grep "status=")"
    case "$status" in
        *speed*|*everything*) ;;
        *)
            log_opt "AOT optimizing: $pkg"
            nice -n 19 cmd package compile -m speed-profile "$pkg" >/dev/null 2>&1
            sleep 2
            ;;
    esac
done

# 3. System Memory, ZRAM & Storage Maintenance
log_opt "Executing storage fstrim, ZRAM defragmentation, and cache trimming..."

# Prune UsageStats protobuf bloat (prevents 15-second unlock lockups)
rm -rf /data/system/usagestats/0/daily/* 2>/dev/null || true

# Prune TrickyStore target list if overpopulated
if [ -f "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" ]; then
    sh "/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh" >/dev/null 2>&1
fi

# Trim caches & defragment ZRAM
pm trim-caches 2G >/dev/null 2>&1
echo 1 > /sys/block/zram0/compact 2>/dev/null || true
fstrim -v /data >/dev/null 2>&1
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Record completion timestamp
date +%Y-%m-%d >"$STAMP_FILE" 2>/dev/null
log_opt "Nightly full system optimization finished successfully."
exit 0
