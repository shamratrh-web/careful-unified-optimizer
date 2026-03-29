#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.1 ThermalGuard Pro
# Optimized for MT6877 (Dimensity 7050) on Android 15

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulThermalGuard}"
STATE_FILE="$MODDIR/.power_mode"
THERMAL_HISTORY_FILE="$MODDIR/.thermal_history"

# Frequency mappings for MT6877
# Little (0-5): 2.0GHz(0) ... 1.6GHz(4) ... 1.05GHz(10) ... 500MHz(15)
# Big (6-7): 2.6GHz(0) ... 2.0GHz(4) ... 1.54GHz(8) ... 650MHz(15)

# Thermal thresholds (millidegrees) - Relaxed for Android 15
THERMAL_NORMAL_MAX=62000      # 62°C CPU / 39°C Battery
THERMAL_ELEVATED_MAX=72000    # 72°C CPU / 43°C Battery
THERMAL_CRITICAL_MAX=82000    # 82°C CPU / 46°C Battery
THERMAL_RECOVERY_TARGET=58000 # 58°C - Target for full release

TEMP_HYSTERESIS=4000  # 4°C hysteresis

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

log_thermal() {
    log -t "$LOG_TAG" "$1"
}

refresh_thermal_cache() {
    CAREFUL_CPU_TEMP=0
    CAREFUL_SHELL_TEMP=0
    CAREFUL_BATTERY_TEMP=0
    CAREFUL_GPU_TEMP=0
    
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        type="$(cat "$zone/type" 2>/dev/null)"
        temp="$(cat "$zone/temp" 2>/dev/null)"
        case "$temp" in ''|*[!0-9-]*) continue ;; esac
        [ "$temp" -lt 0 ] || [ "$temp" -gt 150000 ] && continue
        
        case "$type" in
            mtktscpu|AP_tmp|mtktsAP|cpu-*) [ "$temp" -gt "$CAREFUL_CPU_TEMP" ] && CAREFUL_CPU_TEMP=$temp ;;
            shell_*|skin-*) [ "$temp" -gt "$CAREFUL_SHELL_TEMP" ] && CAREFUL_SHELL_TEMP=$temp ;;
            battery|mtktsbattery) [ "$temp" -gt "$CAREFUL_BATTERY_TEMP" ] && CAREFUL_BATTERY_TEMP=$temp ;;
            gpu-*|mali-*) [ "$temp" -gt "$CAREFUL_GPU_TEMP" ] && CAREFUL_GPU_TEMP=$temp ;;
        esac
    done
}

get_max_temp() {
    refresh_thermal_cache
    echo "$CAREFUL_CPU_TEMP"
}

screen_is_on() {
    dumpsys power 2>/dev/null | grep -qE "mHoldingDisplaySuspendBlocker=true|mWakefulness=Awake" && return 0
    return 1
}

read_power_mode() {
    cat "$STATE_FILE" 2>/dev/null || echo "normal"
}

write_power_mode() {
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}

# PPM Control (The "Right" way for MTK)
set_ppm_limit() {
    local cluster="$1" # 0=Little, 1=Big
    local max_freq="$2" # Freq in KHz or -1 for no limit
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "$cluster $max_freq" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
}

set_gpu_limit() {
    local max_freq="$1" # Freq in KHz
    for p in /sys/class/devfreq/*mali/max_freq /sys/kernel/debug/mali/mali_gpu_max_freq; do
        write_if_exists "$p" "$max_freq"
    done
}

apply_thermal_policy() {
    local state="$1"
    case "$state" in
        critical)
            set_ppm_limit 0 1053000
            set_ppm_limit 1 1300000
            set_gpu_limit 400000
            log_thermal "CRITICAL: Aggressive throttle"
            ;;
        elevated)
            set_ppm_limit 0 1503000
            set_ppm_limit 1 2000000 # 2.0GHz Big cores should be enough for smooth Reels
            set_gpu_limit 600000
            log_thermal "ELEVATED: Balanced throttle"
            ;;
        warm)
            set_ppm_limit 0 1800000
            set_ppm_limit 1 2275000
            set_gpu_limit 800000
            log_thermal "WARM: Soft throttle"
            ;;
        normal)
            set_ppm_limit 0 -1
            set_ppm_limit 1 -1
            set_gpu_limit 950000
            log_thermal "NORMAL: Full performance"
            ;;
    esac
}

apply_battery_guard() {
    set_ppm_limit 0 1053000
    set_ppm_limit 1 1140000
    set_gpu_limit 300000
    write_power_mode "screen_off"
}

restore_normal_limits() {
    apply_thermal_policy "normal"
    write_power_mode "normal"
}

calculate_thermal_state() {
    refresh_thermal_cache
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_CRITICAL_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge 46000 ]; then
        echo "critical"
    elif [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_ELEVATED_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge 42000 ]; then
        echo "elevated"
    elif [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_NORMAL_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge 39000 ]; then
        echo "warm"
    else
        echo "normal"
    fi
}

detect_power_mode() {
    if ! screen_is_on; then echo "screen_off"; return 0; fi
    local state=$(calculate_thermal_state)
    local current=$(read_power_mode)
    
    if [ "$current" = "thermal_guard" ]; then
        if [ "$CAREFUL_CPU_TEMP" -le "$THERMAL_RECOVERY_TARGET" ] && [ "$CAREFUL_BATTERY_TEMP" -le 37000 ]; then
            echo "normal"
        else
            echo "thermal_guard"
        fi
        return 0
    fi
    
    if [ "$state" = "critical" ] || [ "$state" = "elevated" ]; then
        echo "thermal_guard"
    else
        echo "normal"
    fi
}
