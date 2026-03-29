#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.4 Micro-Lag Eliminator
# Surgical Micro-Stutter Fix for MT6877 on Android 15

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulMicroLag}"
STATE_FILE="$MODDIR/.power_mode"

# Thermal thresholds - Performance Bias
THERMAL_NORMAL_MAX=70000      
THERMAL_ELEVATED_MAX=80000    
THERMAL_CRITICAL_MAX=90000    
THERMAL_RECOVERY_TARGET=65000 

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

log_fix() {
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

is_heavy_app() {
    fg_app=$(dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' | head -1)
    case "$fg_app" in
        *instagram*|*tiktok*|*youtube*|*facebook*|*reels*|*video*|*game*|*unity*|*unreal*) return 0 ;;
    esac
    return 1
}

# Zero-Latency Fixes
apply_micro_lag_fix() {
    # 1. MTK GED Boost - Forces GPU to stay awake during UI interactions
    write_if_exists /sys/module/ged/parameters/ged_boost_enable 1
    write_if_exists /sys/module/ged/parameters/ged_smart_boost 1
    write_if_exists /sys/module/ged/parameters/boost_gpu_enable 1
    write_if_exists /sys/module/ged/parameters/gpu_bottom_freq 400000
    
    # 2. I/O Latency - Prevent request merging to reduce wait times for small database reads (FB/Insta)
    for q in /sys/block/*/queue; do
        write_if_exists "$q/nomerges" 2
        write_if_exists "$q/rq_affinity" 2
        write_if_exists "$q/add_random" 0
    done
    
    # 3. Sugov-Ext Immediate Ramp
    write_if_exists /sys/devices/system/cpu/cpufreq/sugov_ext/up_rate_limit_us 0
    write_if_exists /sys/devices/system/cpu/cpufreq/sugov_ext/down_rate_limit_us 50000
    
    # 4. SurfaceFlinger content detection
    settings put system peak_refresh_rate 120.0 2>/dev/null
    service call SurfaceFlinger 1035 i32 1 2>/dev/null
}

apply_video_boost() {
    log_fix "ELIMINATING LAG: Video/Reels prioritized."
    apply_micro_lag_fix
    
    # PPM System Boost
    if [ -w /proc/ppm/policy_status ]; then echo "9 1" > /proc/ppm/policy_status 2>/dev/null; fi
    
    # Clear CPU limits
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "0 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
        echo "1 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
    
    # Performance core pinning
    write_if_exists /dev/cpuset/top-app/cpus 0-7
    write_power_mode "video_boost"
}

apply_thermal_policy() {
    local state="$1"
    case "$state" in
        critical)
            if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
                echo "0 1053000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
                echo "1 1300000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
            fi
            log_fix "CRITICAL: Throttle"
            ;;
        *)
            if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
                echo "0 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
                echo "1 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
            fi
            log_fix "NORMAL: Full performance"
            ;;
    esac
}

restore_normal_limits() {
    apply_micro_lag_fix
    if [ -w /proc/ppm/policy_status ]; then echo "9 0" > /proc/ppm/policy_status 2>/dev/null; fi
    apply_thermal_policy "normal"
    write_power_mode "normal"
}

detect_power_mode() {
    if ! screen_is_on; then echo "screen_off"; return 0; fi
    refresh_thermal_cache
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_CRITICAL_MAX" ]; then echo "thermal_guard"; return 0; fi
    if is_heavy_app; then echo "video_boost"; return 0; fi
    echo "normal"
}

write_power_mode() {
    mkdir -p "$MODDIR" 2>/dev/null
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}
