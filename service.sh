#!/system/bin/sh
# Careful Unified Optimizer v6.0 ThermalGuard Pro - Intelligent Service
# Advanced thermal monitoring with adaptive frequency management

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

# ============================================================================
# SERVICE CONFIGURATION
# ============================================================================

# Monitoring intervals (in seconds)
THERMAL_CHECK_INTERVAL=30      # Check temperature every 30s
ADAPTIVE_INTERVAL=15           # Adaptive adjustment every 15s during load
SCREEN_OFF_INTERVAL=120        # Check every 2min when screen off
WPA_CLEANUP_INTERVAL=180       # WPA cleanup every 3min

# Thermal sampling for accurate readings
THERMAL_SAMPLES=3
THERMAL_SAMPLE_DELAY=1

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

apply_storage_tuning() {
    # I/O scheduler optimization for better battery life
    for queue in /sys/block/dm-*/queue /sys/block/sd*/queue /sys/block/mmcblk*/queue; do
        [ -f "$queue/scheduler" ] || continue
        sched=$(cat "$queue/scheduler" 2>/dev/null)
        case "$sched" in
            *mq-deadline*) echo mq-deadline >"$queue/scheduler" 2>/dev/null ;;
            *none*) ;; # Already optimal
        esac
    done
    
    # Read-ahead optimization
    for block_dev in /sys/block/*/queue/read_ahead_kb; do
        [ -f "$block_dev" ] && echo 128 >"$block_dev" 2>/dev/null
    done
}

# ============================================================================
# THERMAL MONITORING DAEMON
# ============================================================================

thermal_monitor_daemon() {
    log -t "$LOG_TAG" "Thermal monitor daemon started"
    
    local last_action="normal"
    local consecutive_high=0
    local consecutive_low=0
    
    while true; do
        # Determine sleep interval based on screen state
        if screen_is_on; then
            sleep_interval=$THERMAL_CHECK_INTERVAL
        else
            sleep_interval=$SCREEN_OFF_INTERVAL
        fi
        
        sleep $sleep_interval
        
        # Get accurate temperature reading (average of samples)
        refresh_thermal_cache
        avg_cpu_temp=$CAREFUL_CPU_TEMP
        
        # Determine thermal state
        thermal_state=$(calculate_thermal_state)
        current_mode=$(read_power_mode)
        
        # Track consecutive readings for stability
        if [ "$avg_cpu_temp" -ge "$THERMAL_ELEVATED_MAX" ]; then
            consecutive_high=$((consecutive_high + 1))
            consecutive_low=0
        elif [ "$avg_cpu_temp" -le "$THERMAL_RECOVERY_TARGET" ]; then
            consecutive_low=$((consecutive_low + 1))
            consecutive_high=0
        fi
        
        # State machine for thermal actions
        case "$thermal_state" in
            critical)
                # Immediate action required
                if [ "$last_action" != "critical" ] || [ $consecutive_high -ge 2 ]; then
                    apply_thermal_policy "critical"
                    write_power_mode "thermal_guard"
                    last_action="critical"
                    log -t "$LOG_TAG" "CRITICAL: Aggressive throttling applied (${avg_cpu_temp}m°C)"
                fi
                ;;
            elevated)
                # Sustained elevated temperature
                if [ $consecutive_high -ge 2 ]; then
                    apply_thermal_policy "elevated"
                    write_power_mode "thermal_guard"
                    last_action="elevated"
                    log -t "$LOG_TAG" "ELEVATED: Throttling applied (${avg_cpu_temp}m°C, count=$consecutive_high)"
                fi
                ;;
            warm)
                # Light throttling if screen is on
                if screen_is_on && [ "$current_mode" != "screen_off" ]; then
                    apply_thermal_policy "warm"
                    last_action="warm"
                elif [ "$current_mode" = "thermal_guard" ] && [ $consecutive_low -ge 3 ]; then
                    # Recover from thermal guard
                    restore_normal_limits
                    last_action="normal"
                    log -t "$LOG_TAG" "RECOVERY: Returned to normal (${avg_cpu_temp}m°C)"
                fi
                ;;
            normal)
                # Full performance
                if [ "$current_mode" = "thermal_guard" ] && [ $consecutive_low -ge 3 ]; then
                    restore_normal_limits
                    last_action="normal"
                    log -t "$LOG_TAG" "RECOVERY: Normal operation resumed (${avg_cpu_temp}m°C)"
                elif [ "$last_action" != "normal" ]; then
                    reset_cpu_freq
                    reset_gpu_freq
                    last_action="normal"
                fi
                ;;
        esac
        
        # Save thermal snapshot for analysis
        save_thermal_snapshot
    done
}

# ============================================================================
# WPA SUPPLICANT CLEANUP DAEMON
# ============================================================================

wpa_cleanup_daemon() {
    log -t "$LOG_TAG" "WPA cleanup daemon started"
    
    while true; do
        sleep $WPA_CLEANUP_INTERVAL
        cleanup_rogue_wpa_supplicant
    done
}

# ============================================================================
# SMART BALANCE TRIGGER
# ============================================================================

trigger_smart_balance() {
    local trigger_type="$1"
    
    if [ -f "$MODDIR/smart_balance.sh" ]; then
        sh "$MODDIR/smart_balance.sh" "$trigger_type" >/dev/null 2>&1 &
    fi
}

# ============================================================================
# BOOT SEQUENCE
# ============================================================================

# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

log -t "$LOG_TAG" "v6.0 ThermalGuard Pro starting..."

# Initial cleanup
cleanup_rogue_wpa_supplicant

# Apply initial smart balance
trigger_smart_balance "boot"

# Wait for vendor services to settle
sleep 30

# Apply storage tuning
apply_storage_tuning

# Apply VM settings
write_if_exists /proc/sys/vm/dirty_writeback_centisecs 1500
write_if_exists /proc/sys/vm/dirty_expire_centisecs 3000

# Create health monitoring directory
mkdir -p /sdcard/Android/HChai/HC_memory 2>/dev/null
touch /sdcard/Android/HChai/HC_memory/Run.log 2>/dev/null

# ============================================================================
# START DAEMONS
# ============================================================================

# Start thermal monitoring daemon
thermal_monitor_daemon &

# Start WPA cleanup daemon (if not disabled)
if [ "$(getprop persist.careful.allow_termux_wpa)" != "1" ]; then
    wpa_cleanup_daemon &
fi

# Optional: Live module watcher (only if enabled)
if [ "$(getprop persist.careful.live_module_watch)" = "1" ]; then
    (
        previous_list="$(ls -1 /data/adb/modules 2>/dev/null)"
        while true; do
            sleep 120
            current_list="$(ls -1 /data/adb/modules 2>/dev/null)"
            [ "$current_list" = "$previous_list" ] && continue
            log -t "$LOG_TAG" "Module change detected; reapplying properties"
            
            # Reapply system properties from module
            [ -f "$MODDIR/system.prop" ] && resetprop -p --file "$MODDIR/system.prop"
            
            previous_list="$current_list"
        done
    ) &
fi

# Periodic smart balance refresh
(
    while true; do
        sleep 300  # Every 5 minutes
        trigger_smart_balance "auto"
    done
) &

log -t "$LOG_TAG" "v6.0 ThermalGuard Pro initialized successfully"
exit 0
