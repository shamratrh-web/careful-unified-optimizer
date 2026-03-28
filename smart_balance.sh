#!/system/bin/sh
# Careful Unified Optimizer v5.0 - live balance profile

LOG_TAG="CarefulSmartBalance"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

apply_memory_balance() {
    if [ -f /sys/kernel/mm/lru_gen/enabled ]; then
        echo 7 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null || \
        echo 3 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null
    fi

    write_if_exists /proc/sys/vm/swappiness 80
    write_if_exists /proc/sys/vm/vfs_cache_pressure 70
    write_if_exists /proc/sys/vm/dirty_ratio 16
    write_if_exists /proc/sys/vm/dirty_background_ratio 4
    write_if_exists /proc/sys/vm/compaction_proactiveness 30
    write_if_exists /proc/sys/vm/watermark_scale_factor 18
    write_if_exists /proc/sys/vm/page-cluster 0
}

apply_runtime_props() {
    for prop in \
        persist.sys.composition.type \
        persist.sys.force_highend_gfx \
        persist.sys.use_dithering \
        persist.sys.ui.hw \
        persist.sys.powermode; do
        resetprop -p -d "$prop" 2>/dev/null
    done

    for prop in \
        cached_apps_freezer \
        persist.sys.cached_apps_freezer \
        debug.sf.vsync_reinject_ignore \
        logcat.live \
        wifi.supplicant_scan_interval \
        pm.sleep_mode; do
        resetprop -d "$prop" 2>/dev/null
    done

    resetprop persist.sys.smart_ram_management 1 2>/dev/null
    resetprop -p persist.vendor.mtk.perf_turbo 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.enable 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.v2.enable 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.v3.enable 1 2>/dev/null
    resetprop -p debug.sf.latch_unsignaled 1 2>/dev/null
    resetprop -p debug.sf.disable_backpressure 1 2>/dev/null
    resetprop -p persist.sys.boot.logcat 0 2>/dev/null
    resetprop -p persist.logd.logpersistd 0 2>/dev/null
}

force_apply=0
full_apply=0
case "$1" in
    screen_off|thermal_guard|normal)
        target_mode="$1"
        full_apply=1
        ;;
    boot|manual)
        target_mode="$(detect_power_mode)"
        force_apply=1
        full_apply=1
        ;;
    auto|"")
        target_mode="$(detect_power_mode)"
        ;;
    *)
        target_mode="normal"
        force_apply=1
        ;;
esac

if [ "$(getprop sys.boot_completed)" != "1" ]; then
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 2
    done
fi

if [ "$full_apply" = "1" ]; then
    apply_memory_balance
    apply_runtime_props
fi

current_mode="$(read_power_mode)"
if [ "$force_apply" = "1" ] || [ "$current_mode" != "$target_mode" ]; then
    case "$target_mode" in
        screen_off)
            apply_battery_guard
            ;;
        thermal_guard)
            apply_thermal_guard
            ;;
        *)
            restore_normal_limits
            target_mode="normal"
            ;;
    esac
fi

refresh_thermal_cache
log -t "$LOG_TAG" "v5 mode=$target_mode cpu=${CAREFUL_CPU_TEMP:-0} shell=${CAREFUL_SHELL_TEMP:-0} battery=${CAREFUL_BATTERY_TEMP:-0}"
