#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v5.0

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulUnifiedOpt}"
STATE_FILE="$MODDIR/.power_mode"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

list_wpa_supplicant() {
    ps -A -o PID,PPID,USER,NAME,ARGS 2>/dev/null | grep wpa_supplicant | grep -v grep
}

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

max_value() {
    max=0
    for val in "$@"; do
        case "$val" in
            ''|*[!0-9-]*) continue ;;
        esac
        [ "$val" -gt "$max" ] && max="$val"
    done
    echo "$max"
}

refresh_thermal_cache() {
    CAREFUL_CPU_TEMP=0
    CAREFUL_SHELL_TEMP=0
    CAREFUL_BATTERY_TEMP=0

    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        [ -r "$zone/temp" ] || continue

        type="$(cat "$zone/type" 2>/dev/null)"
        temp="$(cat "$zone/temp" 2>/dev/null)"

        case "$temp" in
            ''|*[!0-9-]*) continue ;;
        esac

        case "$type" in
            mtktscpu|AP_tmp|mtktsAP|mtktspa)
                [ "$temp" -gt "$CAREFUL_CPU_TEMP" ] && CAREFUL_CPU_TEMP="$temp"
                ;;
            shell_front|shell_frame|shell_back)
                [ "$temp" -gt "$CAREFUL_SHELL_TEMP" ] && CAREFUL_SHELL_TEMP="$temp"
                ;;
            battery|mtktsbattery)
                [ "$temp" -gt "$CAREFUL_BATTERY_TEMP" ] && CAREFUL_BATTERY_TEMP="$temp"
                ;;
        esac
    done
}

get_cpu_temp() {
    [ -n "${CAREFUL_CPU_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_CPU_TEMP:-0}"
}

get_shell_temp() {
    [ -n "${CAREFUL_SHELL_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_SHELL_TEMP:-0}"
}

get_battery_temp() {
    [ -n "${CAREFUL_BATTERY_TEMP+x}" ] || refresh_thermal_cache
    echo "${CAREFUL_BATTERY_TEMP:-0}"
}

screen_is_on() {
    power_dump="$(dumpsys power 2>/dev/null | sed -n '1,80p')"
    case "$power_dump" in
        *"mHoldingDisplaySuspendBlocker=true"*|*"mWakefulness=Awake"*) return 0 ;;
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

set_userlimit_max() {
    [ -w /proc/ppm/policy/userlimit_max_cpu_freq ] || return 0
    echo "$1 $2" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
}

set_userlimit_min() {
    [ -w /proc/ppm/policy/userlimit_min_cpu_freq ] || return 0
    echo "$1 $2" >/proc/ppm/policy/userlimit_min_cpu_freq 2>/dev/null
}

clear_user_limits() {
    set_userlimit_min 0 -1
    set_userlimit_min 1 -1
    set_userlimit_max 0 -1
    set_userlimit_max 1 -1
}

enable_lcmoff_policy() {
    [ -w /proc/ppm/policy_status ] || return 0
    echo "8 1" >/proc/ppm/policy_status 2>/dev/null
}

disable_lcmoff_policy() {
    [ -w /proc/ppm/policy_status ] || return 0
    echo "8 0" >/proc/ppm/policy_status 2>/dev/null
}

set_lcmoff_min_freq() {
    [ -w /proc/ppm/policy/lcmoff_min_freq ] || return 0
    echo "$1" >/proc/ppm/policy/lcmoff_min_freq 2>/dev/null
}

apply_battery_guard() {
    clear_user_limits
    set_userlimit_max 0 1053000
    set_userlimit_max 1 1300000

    if [ "$(getprop persist.careful.use_lcmoff_policy)" = "1" ]; then
        set_lcmoff_min_freq 500000
        enable_lcmoff_policy
    else
        set_lcmoff_min_freq 0
        disable_lcmoff_policy
    fi

    write_power_mode screen_off
}

apply_thermal_guard() {
    clear_user_limits
    set_userlimit_max 0 1260000
    set_userlimit_max 1 1540000
    set_lcmoff_min_freq 0
    disable_lcmoff_policy
    write_power_mode thermal_guard
}

restore_normal_limits() {
    clear_user_limits
    set_lcmoff_min_freq 0
    disable_lcmoff_policy
    write_power_mode normal
}

detect_power_mode() {
    refresh_thermal_cache
    cpu_temp="${CAREFUL_CPU_TEMP:-0}"
    shell_temp="${CAREFUL_SHELL_TEMP:-0}"
    battery_temp="${CAREFUL_BATTERY_TEMP:-0}"

    if ! screen_is_on; then
        echo screen_off
        return 0
    fi

    if [ "$cpu_temp" -ge 72000 ] || [ "$shell_temp" -ge 44000 ] || [ "$battery_temp" -ge 39000 ]; then
        echo thermal_guard
        return 0
    fi

    echo normal
}
