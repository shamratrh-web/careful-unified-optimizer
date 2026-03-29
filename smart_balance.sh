#!/system/bin/sh
# Careful Unified Optimizer v6.1 ThermalGuard Pro - Live Balance
# Optimized for MT6877 (Dimensity 7050) on Android 15

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"
[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

apply_memory_balance() {
    # MGLRU for Android 15
    write_if_exists /sys/kernel/mm/lru_gen/enabled 7
    
    # ZRAM and Swap optimization for MediaTek
    write_if_exists /proc/sys/vm/swappiness 100
    write_if_exists /proc/sys/vm/vfs_cache_pressure 100
    write_if_exists /proc/sys/vm/dirty_ratio 20
    write_if_exists /proc/sys/vm/dirty_background_ratio 5
    write_if_exists /proc/sys/vm/dirty_writeback_centisecs 500
    write_if_exists /proc/sys/vm/dirty_expire_centisecs 3000
    write_if_exists /proc/sys/vm/page-cluster 0
}

apply_runtime_props() {
    # Ensure freezer is enabled (System settings override)
    device_config put activity_manager_native_boot use_freezer true 2>/dev/null
    
    # MediaTek specific props
    resetprop -p persist.vendor.mtk.perf_turbo 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.enable 1 2>/dev/null
}

# Main Logic
target_mode="$1"
full_apply=0

case "$target_mode" in
    boot|manual)
        target_mode="$(detect_power_mode)"
        full_apply=1
        ;;
    auto|"")
        target_mode="$(detect_power_mode)"
        ;;
esac

if [ "$full_apply" = "1" ]; then
    apply_memory_balance
    apply_runtime_props
fi

current_mode="$(read_power_mode)"
if [ "$current_mode" != "$target_mode" ] || [ "$full_apply" = "1" ]; then
    case "$target_mode" in
        screen_off)
            apply_battery_guard
            ;;
        thermal_guard)
            # Re-detect the specific state for proportional throttling
            state=$(calculate_thermal_state)
            apply_thermal_policy "$state"
            write_power_mode "thermal_guard"
            ;;
        *)
            restore_normal_limits
            ;;
    esac
fi

# Final log
refresh_thermal_cache
log_thermal "v6.1 mode=$target_mode cpu=${CAREFUL_CPU_TEMP} battery=${CAREFUL_BATTERY_TEMP}"
