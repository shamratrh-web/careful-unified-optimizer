#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.0 ThermalGuard Pro
# Advanced thermal-aware frequency management for MT6877

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulThermalGuard}"
STATE_FILE="$MODDIR/.power_mode"
THERMAL_HISTORY_FILE="$MODDIR/.thermal_history"

# Frequency thresholds for MT6877 (Dimensity 7050)
# Little cores (A55): 500MHz - 2000MHz
# Big cores (A78): 650MHz - 2500MHz
LITTLE_MIN_FREQ=500000
LITTLE_MAX_FREQ=2000000
BIG_MIN_FREQ=650000
BIG_MAX_FREQ=2500000

# Thermal thresholds (in millidegrees Celsius)
THERMAL_NORMAL_MAX=55000      # 55°C - comfortable operating temp
THERMAL_ELEVATED_MAX=65000    # 65°C - start throttling
THERMAL_CRITICAL_MAX=75000    # 75°C - aggressive throttling
THERMAL_RECOVERY_TARGET=50000 # 50°C - recover from thermal guard

# Temperature hysteresis (prevent oscillation)
TEMP_HYSTERESIS=3000  # 3°C hysteresis

# ============================================================================
# CORE UTILITIES
# ============================================================================

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

write_if_exists_batch() {
    local file="$1"
    local value="$2"
    [ -e "$file" ] && echo "$value" >"$file" 2>/dev/null
}

log_thermal() {
    log -t "$LOG_TAG" "$1"
}

# ============================================================================
# THERMAL MONITORING
# ============================================================================

refresh_thermal_cache() {
    CAREFUL_CPU_TEMP=0
    CAREFUL_SHELL_TEMP=0
    CAREFUL_BATTERY_TEMP=0
    CAREFUL_GPU_TEMP=0
    CAREFUL_CHARGING_TEMP=0
    
    # Read all thermal zones
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        [ -r "$zone/temp" ] || continue
        
        type="$(cat "$zone/type" 2>/dev/null)"
        temp="$(cat "$zone/temp" 2>/dev/null)"
        
        # Validate temperature reading
        case "$temp" in
            ''|*[!0-9-]*) continue ;;
        esac
        
        # Skip invalid readings (too low or too high)
        [ "$temp" -lt 0 ] 2>/dev/null && continue
        [ "$temp" -gt 150000 ] 2>/dev/null && continue
        
        # Categorize thermal zones
        case "$type" in
            mtktscpu|AP_tmp|mtktsAP|mtktspa|cpu-*|CPU*)
                [ "$temp" -gt "$CAREFUL_CPU_TEMP" ] && CAREFUL_CPU_TEMP="$temp"
                ;;
            shell_front|shell_frame|shell_back|skin-*)
                [ "$temp" -gt "$CAREFUL_SHELL_TEMP" ] && CAREFUL_SHELL_TEMP="$temp"
                ;;
            battery|mtktsbattery|bms-*)
                [ "$temp" -gt "$CAREFUL_BATTERY_TEMP" ] && CAREFUL_BATTERY_TEMP="$temp"
                ;;
            gpu-*|GPU*|mali-*)
                [ "$temp" -gt "$CAREFUL_GPU_TEMP" ] && CAREFUL_GPU_TEMP="$temp"
                ;;
            charging-*|charger-*)
                [ "$temp" -gt "$CAREFUL_CHARGING_TEMP" ] && CAREFUL_CHARGING_TEMP="$temp"
                ;;
        esac
    done
    
    # Fallback: if specific zones not found, use highest temp
    [ "$CAREFUL_CPU_TEMP" -eq 0 ] && CAREFUL_CPU_TEMP="$CAREFUL_SHELL_TEMP"
    [ "$CAREFUL_GPU_TEMP" -eq 0 ] && CAREFUL_GPU_TEMP="$CAREFUL_CPU_TEMP"
}

get_max_temp() {
    refresh_thermal_cache
    max_temp=0
    for temp in "$CAREFUL_CPU_TEMP" "$CAREFUL_GPU_TEMP" "$CAREFUL_BATTERY_TEMP" "$CAREFUL_SHELL_TEMP"; do
        [ "$temp" -gt "$max_temp" ] 2>/dev/null && max_temp="$temp"
    done
    echo "$max_temp"
}

get_cpu_temp() {
    [ -n "${CAREFUL_CPU_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_CPU_TEMP:-0}"
}

get_gpu_temp() {
    [ -n "${CAREFUL_GPU_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_GPU_TEMP:-0}"
}

get_battery_temp() {
    [ -n "${CAREFUL_BATTERY_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_BATTERY_TEMP:-0}"
}

# ============================================================================
# POWER STATE MANAGEMENT
# ============================================================================

screen_is_on() {
    power_dump="$(dumpsys power 2>/dev/null | sed -n '1,80p')"
    case "$power_dump" in
        *"mHoldingDisplaySuspendBlocker=true"*|*"mWakefulness=Awake"*) return 0 ;;
    esac
    return 1
}

is_charging() {
    charge_status="$(dumpsys battery 2>/dev/null | grep -E 'AC powered|USB powered|Wireless powered')"
    case "$charge_status" in
        *true*) return 0 ;;
    esac
    return 1
}

read_power_mode() {
    [ -f "$STATE_FILE" ] || {
        echo normal
        return 0
    }
    cat "$STATE_FILE" 2>/dev/null
}

write_power_mode() {
    mkdir -p "$MODDIR" 2>/dev/null
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}

# ============================================================================
# CPU FREQUENCY CONTROL
# ============================================================================

set_cpu_freq_range() {
    local policy="$1"
    local min_freq="$2"
    local max_freq="$3"
    
    # Set min first, then max (prevents conflicts)
    write_if_exists "/sys/devices/system/cpu/cpufreq/${policy}/scaling_min_freq" "$min_freq"
    write_if_exists "/sys/devices/system/cpu/cpufreq/${policy}/scaling_max_freq" "$max_freq"
}

set_all_cpu_freq() {
    local min_freq="$1"
    local max_freq="$2"
    
    # Little cores (policy0 typically)
    set_cpu_freq_range "policy0" "$min_freq" "$max_freq"
    
    # Big cores (policy6 typically on octa-core)
    set_cpu_freq_range "policy6" "$min_freq" "$max_freq"
}

reset_cpu_freq() {
    # Restore to default frequencies
    set_cpu_freq_range "policy0" "$LITTLE_MIN_FREQ" "$LITTLE_MAX_FREQ"
    set_cpu_freq_range "policy6" "$BIG_MIN_FREQ" "$BIG_MAX_FREQ"
}

# ============================================================================
# GPU FREQUENCY CONTROL (Mali-G68 MC4)
# ============================================================================

set_gpu_freq_range() {
    local min_freq="$1"
    local max_freq="$2"
    
    # Try multiple possible paths for Mali GPU
    for gpu_path in \
        /sys/devices/platform/soc/14007000.mali/devfreq/14007000.mali \
        /sys/devices/platform/gpu/devfreq/gpu \
        /sys/class/devfreq/gpu \
        /sys/class/devfreq/14007000.mali; do
        
        if [ -d "$gpu_path" ]; then
            write_if_exists "$gpu_path/min_freq" "$min_freq"
            write_if_exists "$gpu_path/max_freq" "$max_freq"
            return 0
        fi
    done
}

reset_gpu_freq() {
    # Remove GPU frequency limits
    for gpu_path in \
        /sys/devices/platform/soc/14007000.mali/devfreq/14007000.mali \
        /sys/devices/platform/gpu/devfreq/gpu \
        /sys/class/devfreq/gpu; do
        
        [ -d "$gpu_path" ] || continue
        echo 0 > "$gpu_path/min_freq" 2>/dev/null
        cat "$gpu_path/available_frequencies" 2>/dev/null | awk '{print $NF}' > "$gpu_path/max_freq" 2>/dev/null
    done
}

# ============================================================================
# ADAPTIVE THERMAL POLICY
# ============================================================================

calculate_thermal_state() {
    refresh_thermal_cache
    max_temp=$(get_max_temp)
    
    # Determine thermal state with hysteresis
    if [ "$max_temp" -ge "$THERMAL_CRITICAL_MAX" ]; then
        echo "critical"
    elif [ "$max_temp" -ge "$THERMAL_ELEVATED_MAX" ]; then
        echo "elevated"
    elif [ "$max_temp" -ge "$THERMAL_NORMAL_MAX" ]; then
        echo "warm"
    else
        echo "normal"
    fi
}

apply_thermal_policy() {
    local state="$1"
    
    case "$state" in
        critical)
            # Aggressive cooling - limit both CPU and GPU significantly
            set_all_cpu_freq 500000 1200000
            set_gpu_freq_range 200000 400000
            log_thermal "CRITICAL: Max throttling applied (temp: ${CAREFUL_CPU_TEMP}m°C)"
            ;;
        elevated)
            # Moderate throttling - balance between performance and cooling
            set_all_cpu_freq 600000 1600000
            set_gpu_freq_range 300000 600000
            log_thermal "ELEVATED: Moderate throttling (temp: ${CAREFUL_CPU_TEMP}m°C)"
            ;;
        warm)
            # Light throttling - slight frequency reduction
            set_all_cpu_freq 700000 1900000
            set_gpu_freq_range 400000 800000
            log_thermal "WARM: Light throttling (temp: ${CAREFUL_CPU_TEMP}m°C)"
            ;;
        normal)
            # Full performance - no limits
            reset_cpu_freq
            reset_gpu_freq
            log_thermal "NORMAL: Full performance (temp: ${CAREFUL_CPU_TEMP}m°C)"
            ;;
    esac
}

# ============================================================================
# POWER MODE ACTIONS
# ============================================================================

apply_battery_guard() {
    # Screen-off state - minimize background activity
    reset_cpu_freq
    set_all_cpu_freq 500000 1000000
    set_gpu_freq_range 200000 400000
    write_power_mode "screen_off"
    log_thermal "SCREEN_OFF: Battery guard active"
}

apply_thermal_guard() {
    # Thermal protection mode
    apply_thermal_policy "elevated"
    write_power_mode "thermal_guard"
}

restore_normal_limits() {
    # Normal operation - full performance within thermal limits
    reset_cpu_freq
    reset_gpu_freq
    write_power_mode "normal"
    log_thermal "NORMAL: All limits restored"
}

# ============================================================================
# SMART THERMAL RECOVERY
# ============================================================================

should_recover_from_thermal() {
    refresh_thermal_cache
    
    # Only recover if temperature is below recovery target with hysteresis
    if [ "$CAREFUL_CPU_TEMP" -le "$((THERMAL_RECOVERY_TARGET - TEMP_HYSTERESIS))" ] && \
       [ "$CAREFUL_GPU_TEMP" -le "$((THERMAL_RECOVERY_TARGET - TEMP_HYSTERESIS))" ] && \
       [ "$CAREFUL_BATTERY_TEMP" -le "$((THERMAL_RECOVERY_TARGET - TEMP_HYSTERESIS))" ]; then
        return 0
    fi
    return 1
}

detect_power_mode() {
    refresh_thermal_cache
    max_temp=$(get_max_temp)
    current_mode="$(read_power_mode)"
    
    # Check screen state first
    if ! screen_is_on; then
        echo "screen_off"
        return 0
    fi
    
    # Thermal recovery logic with hysteresis
    if [ "$current_mode" = "thermal_guard" ]; then
        if should_recover_from_thermal; then
            echo "normal"
            return 0
        fi
        echo "thermal_guard"
        return 0
    fi
    
    # Thermal entry logic
    if [ "$max_temp" -ge "$THERMAL_ELEVATED_MAX" ]; then
        echo "thermal_guard"
        return 0
    fi
    
    echo "normal"
}

# ============================================================================
# THERMAL HISTORY TRACKING
# ============================================================================

save_thermal_snapshot() {
    local timestamp=$(date +%s)
    refresh_thermal_cache
    echo "$timestamp ${CAREFUL_CPU_TEMP} ${CAREFUL_GPU_TEMP} ${CAREFUL_BATTERY_TEMP}" >> "$THERMAL_HISTORY_FILE"
    
    # Keep only last 100 entries
    if [ -f "$THERMAL_HISTORY_FILE" ]; then
        tail -100 "$THERMAL_HISTORY_FILE" > "${THERMAL_HISTORY_FILE}.tmp"
        mv "${THERMAL_HISTORY_FILE}.tmp" "$THERMAL_HISTORY_FILE"
    fi
}

get_thermal_trend() {
    [ -f "$THERMAL_HISTORY_FILE" ] || {
        echo "stable"
        return 0
    }
    
    # Get last 5 readings
    recent=$(tail -5 "$THERMAL_HISTORY_FILE" 2>/dev/null)
    [ -z "$recent" ] && { echo "stable"; return 0; }
    
    # Calculate trend (simplified)
    first_temp=$(echo "$recent" | head -1 | awk '{print $2}')
    last_temp=$(echo "$recent" | tail -1 | awk '{print $2}')
    
    if [ "$last_temp" -gt "$((first_temp + 5000))" ] 2>/dev/null; then
        echo "rising"
    elif [ "$last_temp" -lt "$((first_temp - 5000))" ] 2>/dev/null; then
        echo "falling"
    else
        echo "stable"
    fi
}

# ============================================================================
# CLEANUP UTILITIES
# ============================================================================

cleanup_rogue_wpa_supplicant() {
    [ "$(getprop persist.careful.allow_termux_wpa)" = "1" ] && return 0

    for proc in /proc/[0-9]*; do
        [ -r "$proc/cmdline" ] || continue
        pid="${proc#/proc/}"
        cmdline="$(tr '\000' ' ' <"$proc/cmdline" 2>/dev/null)"

        case "$cmdline" in
            *"/vendor/bin/hw/wpa_supplicant"*) continue ;;
            *"wpa_supplicant"*"/data/data/com.termux/files/usr/tmp/"*)
                log -t "$LOG_TAG" "Killing rogue wpa_supplicant pid=$pid"
                kill "$pid" 2>/dev/null
                sleep 1
                kill -9 "$pid" 2>/dev/null
                ;;
        esac
    done
}
