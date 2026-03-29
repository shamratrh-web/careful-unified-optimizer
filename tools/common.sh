#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.2 Gaming Pro
# High-performance tuning for MT6877 (Dimensity 7050) on Android 15

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulGamingPro}"
STATE_FILE="$MODDIR/.power_mode"

# Thermal thresholds - Raised for Gaming Pro
THERMAL_NORMAL_MAX=65000      
THERMAL_ELEVATED_MAX=75000    
THERMAL_CRITICAL_MAX=85000    
THERMAL_RECOVERY_TARGET=60000 

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

log_perfmgr() {
    log -t "$LOG_TAG" "$1"
}

refresh_thermal_cache() {
    CAREFUL_CPU_TEMP=0
    CAREFUL_BATTERY_TEMP=0
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        type="$(cat "$zone/type" 2>/dev/null)"
        temp="$(cat "$zone/temp" 2>/dev/null)"
        case "$temp" in ''|*[!0-9-]*) continue ;; esac
        case "$type" in
            mtktscpu|AP_tmp|mtktsAP|cpu-*) [ "$temp" -gt "$CAREFUL_CPU_TEMP" ] && CAREFUL_CPU_TEMP=$temp ;;
            battery|mtktsbattery) [ "$temp" -gt "$CAREFUL_BATTERY_TEMP" ] && CAREFUL_BATTERY_TEMP=$temp ;;
        esac
    done
}

screen_is_on() {
    dumpsys power 2>/dev/null | grep -qE "mHoldingDisplaySuspendBlocker=true|mWakefulness=Awake" && return 0
    return 1
}

is_gaming() {
    # Detect if a game is in the foreground using window dump
    # Looking for surface names or activity names commonly used in games
    fg_app=$(dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' | head -1)
    case "$fg_app" in
        *unity*|*unreal*|*cocos*|*pubg*|*freefire*|*genshin*|*mobile.legends*|*cod.mobile*|*game*) return 0 ;;
    esac
    return 1
}

# PPM Control
set_ppm_policy() {
    local policy_idx="$1" # 7=User Limit, 9=Sys Boost
    local enable="$2"     # 1=On, 0=Off
    if [ -w /proc/ppm/policy_status ]; then
        echo "$policy_idx $enable" >/proc/ppm/policy_status 2>/dev/null
    fi
}

set_ppm_limit() {
    local cluster="$1" 
    local max_freq="$2" 
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "$cluster $max_freq" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
}

# FPSGO / HyperEngine Control
enable_fpsgo() {
    write_if_exists /sys/kernel/fpsgo/common/fpsgo_enable 1
    write_if_exists /proc/perfmgr/perf_ioctl "1 1" # Enable perfmanager
}

apply_turbo_mode() {
    log_perfmgr "TURBO: Gaming detected. Enabling System Boost."
    
    # Enable PPM System Boost (Policy 9)
    set_ppm_policy 9 1
    
    # Remove all CPU limits
    set_ppm_limit 0 -1
    set_ppm_limit 1 -1
    
    # Pin top-app to performance cores (6-7)
    write_if_exists /dev/cpuset/top-app/cpus 0-7 # All cores available
    write_if_exists /dev/cpuset/foreground/cpus 4-7 # Performance cores preferred
    
    enable_fpsgo
    write_power_mode "turbo"
}

apply_thermal_policy() {
    local state="$1"
    set_ppm_policy 9 0 # Disable Turbo/Sys Boost if thermal is triggered
    
    case "$state" in
        critical)
            set_ppm_limit 0 1053000
            set_ppm_limit 1 1300000
            log_perfmgr "CRITICAL: Aggressive thermal throttle"
            ;;
        elevated)
            set_ppm_limit 0 1503000
            set_ppm_limit 1 2000000 
            log_perfmgr "ELEVATED: Balanced thermal throttle"
            ;;
        normal)
            set_ppm_limit 0 -1
            set_ppm_limit 1 -1
            log_perfmgr "NORMAL: Full performance mode"
            ;;
    esac
}

restore_normal_limits() {
    set_ppm_policy 9 0
    apply_thermal_policy "normal"
    write_power_mode "normal"
}

calculate_thermal_state() {
    refresh_thermal_cache
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_CRITICAL_MAX" ]; then echo "critical"
    elif [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_ELEVATED_MAX" ]; then echo "elevated"
    else echo "normal"; fi
}

detect_power_mode() {
    if ! screen_is_on; then echo "screen_off"; return 0; fi
    
    # Gaming detection has absolute priority over non-critical thermal states
    if is_gaming; then
        refresh_thermal_cache
        if [ "$CAREFUL_CPU_TEMP" -lt "$THERMAL_CRITICAL_MAX" ]; then
            echo "turbo"
            return 0
        fi
    fi
    
    local state=$(calculate_thermal_state)
    local current=$(cat "$STATE_FILE" 2>/dev/null)
    
    if [ "$current" = "thermal_guard" ]; then
        [ "$CAREFUL_CPU_TEMP" -le "$THERMAL_RECOVERY_TARGET" ] && echo "normal" || echo "thermal_guard"
        return 0
    fi
    
    [ "$state" != "normal" ] && echo "thermal_guard" || echo "normal"
}

write_power_mode() {
    mkdir -p "$MODDIR" 2>/dev/null
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}
