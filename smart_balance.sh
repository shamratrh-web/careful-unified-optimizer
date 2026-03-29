#!/system/bin/sh
# Careful Unified Optimizer v6.3 Ultimate Smoothness - Live Balance
# Optimized for MT6877 (Dimensity 7050) on Android 15

LOG_TAG="CarefulSmoothness"
MODDIR="${0%/*}"
[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

apply_memory_balance() {
    write_if_exists /sys/kernel/mm/lru_gen/enabled 7
    write_if_exists /proc/sys/vm/swappiness 100
    write_if_exists /proc/sys/vm/vfs_cache_pressure 100
}

apply_runtime_props() {
    device_config put activity_manager_native_boot use_freezer true 2>/dev/null
    # Fix for Reels lag: Prioritize media codecs and surfaceflinger
    resetprop -p persist.sys.media.priority 1 2>/dev/null
    resetprop -p debug.sf.latch_unsignaled 1 2>/dev/null
}

target_mode="$1"
case "$target_mode" in
    boot|manual)
        target_mode="$(detect_power_mode)"
        apply_memory_balance
        apply_runtime_props
        ;;
    auto|"")
        target_mode="$(detect_power_mode)"
        ;;
esac

current_mode=$(cat "$MODDIR/.power_mode" 2>/dev/null)

if [ "$current_mode" != "$target_mode" ] || [ "$target_mode" = "turbo" ] || [ "$target_mode" = "video_boost" ]; then
    case "$target_mode" in
        video_boost)
            apply_video_boost
            ;;
        turbo)
            apply_turbo_mode
            ;;
        screen_off)
            apply_battery_guard
            ;;
        thermal_guard)
            state=$(calculate_thermal_state)
            apply_thermal_policy "$state"
            write_power_mode "thermal_guard"
            ;;
        *)
            restore_normal_limits
            ;;
    esac
fi

refresh_thermal_cache
log_smoothness "v6.3 mode=$target_mode cpu=${CAREFUL_CPU_TEMP} bat=${CAREFUL_BATTERY_TEMP}"
