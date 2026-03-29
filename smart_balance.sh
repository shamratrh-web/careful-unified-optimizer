#!/system/bin/sh
# Careful Unified Optimizer v6.0 ThermalGuard Pro - Adaptive Thermal Balance
# Real-time thermal-aware frequency management for MT6877 (Dimensity 7050)

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

# ============================================================================
# MEMORY & VM OPTIMIZATIONS
# ============================================================================

apply_memory_balance() {
    # LRU Gen enabled for efficient memory management (Android 15 feature)
    if [ -f /sys/kernel/mm/lru_gen/enabled ]; then
        echo 7 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null || \
        echo 3 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null
    fi

    # Balanced VM parameters for 8GB RAM
    # Lower swappiness = less swapping, better for flash storage longevity
    write_if_exists /proc/sys/vm/swappiness 60
    
    # Reduce VFS cache pressure slightly
    write_if_exists /proc/sys/vm/vfs_cache_pressure 50
    
    # Dirty page writeback - balance between I/O bursts and smooth writes
    write_if_exists /proc/sys/vm/dirty_ratio 20
    write_if_exists /proc/sys/vm/dirty_background_ratio 5
    
    # Proactive compaction for better memory utilization
    write_if_exists /proc/sys/vm/compaction_proactiveness 20
    
    # Watermark scale for better memory allocation under pressure
    write_if_exists /proc/sys/vm/watermark_scale_factor 15
    
    # Disable read-ahead for random I/O (common in mobile workloads)
    write_if_exists /proc/sys/vm/page-cluster 0
    
    # Dirty writeback timing - reduced for better responsiveness
    write_if_exists /proc/sys/vm/dirty_writeback_centisecs 1500
    write_if_exists /proc/sys/vm/dirty_expire_centisecs 3000
}

# ============================================================================
# RUNTIME PROPERTY MANAGEMENT
# ============================================================================

apply_runtime_props() {
    # Remove any conflicting properties from previous versions
    for prop in \
        persist.sys.composition.type \
        persist.sys.force_highend_gfx \
        persist.sys.use_dithering \
        persist.sys.ui.hw \
        persist.sys.powermode \
        persist.vendor.mtk.powerhal_boost; do
        resetprop -p -d "$prop" 2>/dev/null
    done

    # Ensure our optimized properties are active
    resetprop -p persist.sys.smart_ram_management 1 2>/dev/null
    resetprop -p persist.vendor.mtk.perf_turbo 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.enable 1 2>/dev/null
    resetprop -p debug.sf.latch_unsignaled 1 2>/dev/null
    resetprop -p persist.sys.boot.logcat 0 2>/dev/null
    resetprop -p persist.logd.logpersistd 0 2>/dev/null
}

# ============================================================================
# ADAPTIVE THERMAL LOOP
# ============================================================================

apply_adaptive_thermal_policy() {
    local thermal_state=$(calculate_thermal_state)
    local thermal_trend=$(get_thermal_trend)
    
    # Apply base policy based on thermal state
    apply_thermal_policy "$thermal_state"
    
    # Adjust based on trend
    case "$thermal_trend" in
        rising)
            # Temperature is rising - be more aggressive
            if [ "$thermal_state" = "warm" ]; then
                # Pre-emptively throttle if rising fast
                set_all_cpu_freq 650000 1700000
                log_thermal "PRE-EMPTIVE: Rising temp trend detected"
            fi
            ;;
        falling)
            # Temperature dropping - can be more relaxed
            if [ "$thermal_state" = "elevated" ]; then
                # Don't throttle as hard if cooling down
                set_all_cpu_freq 650000 1750000
                log_thermal "RECOVERY: Temp trend falling"
            fi
            ;;
    esac
    
    # Save thermal snapshot for trend analysis
    save_thermal_snapshot
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

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

# Wait for boot completion if needed
if [ "$(getprop sys.boot_completed)" != "1" ]; then
    log_thermal "Waiting for boot completion..."
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 2
    done
    log_thermal "Boot complete"
fi

# Apply memory and property settings
if [ "$full_apply" = "1" ]; then
    apply_memory_balance
    apply_runtime_props
fi

# Determine current state and apply appropriate policy
current_mode="$(read_power_mode)"
max_temp=$(get_max_temp)

# Force mode change if requested
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
else
    # Auto mode - apply adaptive thermal policy
    apply_adaptive_thermal_policy
fi

# Log current status
refresh_thermal_cache
log_thermal "v6.0 mode=$target_mode cpu=${CAREFUL_CPU_TEMP}m°C gpu=${CAREFUL_GPU_TEMP}m°C battery=${CAREFUL_BATTERY_TEMP}m°C trend=$(get_thermal_trend)"

exit 0
