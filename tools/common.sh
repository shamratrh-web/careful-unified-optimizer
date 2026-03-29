#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.3 Ultimate Smoothness
# Targeted Reels & Video Stutter Fix for MT6877 on Android 15

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulSmoothness}"
STATE_FILE="$MODDIR/.power_mode"

# Thermal thresholds - Relaxed for Ultimate Smoothness
THERMAL_NORMAL_MAX=68000      
THERMAL_ELEVATED_MAX=78000    
THERMAL_CRITICAL_MAX=88000    
THERMAL_RECOVERY_TARGET=62000 

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

log_smoothness() {
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

is_video_app() {
    # Detect if a video-heavy app is in the foreground
    fg_app=$(dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' | head -1)
    case "$fg_app" in
        *instagram*|*tiktok*|*youtube*|*facebook*|*reels*|*video*) return 0 ;;
    esac
    return 1
}

is_gaming() {
    fg_app=$(dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' | head -1)
    case "$fg_app" in
        *unity*|*unreal*|*cocos*|*pubg*|*freefire*|*genshin*|*mobile.legends*|*cod.mobile*|*game*) return 0 ;;
    esac
    return 1
}

force_high_refresh() {
    # Force 120Hz system-wide (Realme/Oppo/MTK)
    service call SurfaceFlinger 1035 i32 1 2>/dev/null # Lock to mode 1 (typically 120Hz)
    settings put system peak_refresh_rate 120.0 2>/dev/null
    settings put system min_refresh_rate 120.0 2>/dev/null
}

apply_video_boost() {
    log_smoothness "BOOST: Video/Reels detected. Applying smooth profile."
    
    # 1. Force 120Hz
    force_high_refresh
    
    # 2. MTK PPM Policy 9 (System Boost)
    if [ -w /proc/ppm/policy_status ]; then
        echo "9 1" > /proc/ppm/policy_status 2>/dev/null
    fi
    
    # 3. CPU Cluster Limits - Keep Big cores alive
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "0 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
        echo "1 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
    
    # 4. Pin top-app to performance cores
    write_if_exists /dev/cpuset/top-app/cpus 0-7
    
    # 5. Media Codec Priority
    write_if_exists /proc/perfmgr/perf_ioctl "1 1"
    
    write_power_mode "video_boost"
}

apply_turbo_mode() {
    log_smoothness "TURBO: Gaming detected. Ultimate performance active."
    force_high_refresh
    if [ -w /proc/ppm/policy_status ]; then echo "9 1" > /proc/ppm/policy_status 2>/dev/null; fi
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "0 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
        echo "1 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
    write_if_exists /sys/kernel/fpsgo/common/fpsgo_enable 1
    write_power_mode "turbo"
}

apply_thermal_policy() {
    local state="$1"
    case "$state" in
        critical)
            if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
                echo "0 1053000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
                echo "1 1300000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
            fi
            log_smoothness "CRITICAL: Aggressive thermal throttle"
            ;;
        elevated)
            if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
                echo "0 1503000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
                echo "1 2000000" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
            fi
            log_smoothness "ELEVATED: Balanced thermal throttle"
            ;;
        normal)
            if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
                echo "0 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
                echo "1 -1" > /proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
            fi
            log_smoothness "NORMAL: Full performance mode"
            ;;
    esac
}

restore_normal_limits() {
    if [ -w /proc/ppm/policy_status ]; then echo "9 0" > /proc/ppm/policy_status 2>/dev/null; fi
    apply_thermal_policy "normal"
    write_power_mode "normal"
}

detect_power_mode() {
    if ! screen_is_on; then echo "screen_off"; return 0; fi
    
    # Priority 1: Critical Thermal
    refresh_thermal_cache
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_CRITICAL_MAX" ]; then echo "thermal_guard"; return 0; fi
    
    # Priority 2: Gaming
    if is_gaming; then echo "turbo"; return 0; fi
    
    # Priority 3: Video / Reels
    if is_video_app; then echo "video_boost"; return 0; fi
    
    # Priority 4: Normal Thermal Checks
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_ELEVATED_MAX" ]; then echo "thermal_guard"; return 0; fi
    
    echo "normal"
}

write_power_mode() {
    mkdir -p "$MODDIR" 2>/dev/null
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}
