#!/system/bin/sh
# Shared helpers for Careful Unified Optimizer v6.5 Balanced ThermalGuard.

MODDIR="${MODDIR:-/data/adb/modules/careful_optimization}"
LOG_TAG="${LOG_TAG:-CarefulThermalGuard}"
STATE_FILE="$MODDIR/.power_mode"
THERMAL_HISTORY_FILE="$MODDIR/.thermal_history"

THERMAL_NORMAL_MAX=65000
THERMAL_ELEVATED_MAX=75000
THERMAL_CRITICAL_MAX=82000
THERMAL_RECOVERY_TARGET=60000

BATTERY_WARM_MAX=39000
BATTERY_ELEVATED_MAX=42000
BATTERY_CRITICAL_MAX=45000
BATTERY_RECOVERY_TARGET=37000

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

delete_prop_if_possible() {
    resetprop --delete "$1" 2>/dev/null || true
}

log_msg() {
    log -t "$LOG_TAG" "$1"
}

log_thermal() {
    log_msg "$1"
}

log_fix() {
    log_msg "$1"
}

refresh_thermal_cache() {
    CAREFUL_CPU_TEMP=0
    CAREFUL_SHELL_TEMP=0
    CAREFUL_BATTERY_TEMP=0
    CAREFUL_GPU_TEMP=0

    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        [ -r "$zone/temp" ] || continue
        type="$(cat "$zone/type" 2>/dev/null)"
        temp="$(cat "$zone/temp" 2>/dev/null)"
        case "$temp" in
            ''|*[!0-9-]*) continue ;;
        esac
        [ "$temp" -lt 0 ] && continue
        [ "$temp" -gt 150000 ] && continue

        case "$type" in
            mtktscpu|AP_tmp|mtktsAP|cpu-*)
                [ "$temp" -gt "$CAREFUL_CPU_TEMP" ] && CAREFUL_CPU_TEMP=$temp
                ;;
            shell_*|skin-*|shell_front|shell_frame|shell_back)
                [ "$temp" -gt "$CAREFUL_SHELL_TEMP" ] && CAREFUL_SHELL_TEMP=$temp
                ;;
            battery|mtktsbattery)
                [ "$temp" -gt "$CAREFUL_BATTERY_TEMP" ] && CAREFUL_BATTERY_TEMP=$temp
                ;;
            gpu-*|mali-*)
                [ "$temp" -gt "$CAREFUL_GPU_TEMP" ] && CAREFUL_GPU_TEMP=$temp
                ;;
        esac
    done
}

get_cpu_temp() {
    refresh_thermal_cache
    echo "$CAREFUL_CPU_TEMP"
}

get_shell_temp() {
    refresh_thermal_cache
    echo "$CAREFUL_SHELL_TEMP"
}

get_battery_temp() {
    refresh_thermal_cache
    echo "$CAREFUL_BATTERY_TEMP"
}

screen_is_on() {
    dumpsys power 2>/dev/null | grep -qE "mHoldingDisplaySuspendBlocker=true|mWakefulness=Awake" && return 0
    return 1
}

is_heavy_app() {
    fg_app="$(dumpsys window windows 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | head -1)"
    case "$fg_app" in
        *instagram*|*facebook*|*katana*|*orca*|*youtube*|*morphe*|*vanced*|*revanced*|*reddit*|*tiktok*|*shorts*|*video*|*game*|*unity*|*unreal*|*chrome*|*browser*)
            return 0
            ;;
    esac
    return 1
}

read_power_mode() {
    cat "$STATE_FILE" 2>/dev/null || echo "normal"
}

write_power_mode() {
    mkdir -p "$MODDIR" 2>/dev/null
    printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null
}

append_thermal_history() {
    mkdir -p "$MODDIR" 2>/dev/null
    refresh_thermal_cache
    printf '%s mode=%s cpu=%s shell=%s battery=%s gpu=%s\n' \
        "$(date +%s)" \
        "$(read_power_mode)" \
        "$CAREFUL_CPU_TEMP" \
        "$CAREFUL_SHELL_TEMP" \
        "$CAREFUL_BATTERY_TEMP" \
        "$CAREFUL_GPU_TEMP" >>"$THERMAL_HISTORY_FILE" 2>/dev/null

    if [ -f "$THERMAL_HISTORY_FILE" ]; then
        tail -n 120 "$THERMAL_HISTORY_FILE" >"$THERMAL_HISTORY_FILE.tmp" 2>/dev/null
        mv -f "$THERMAL_HISTORY_FILE.tmp" "$THERMAL_HISTORY_FILE" 2>/dev/null
    fi
}

save_thermal_snapshot() {
    append_thermal_history
}

clear_cpu_limits() {
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "0 -1" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
        echo "1 -1" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
    for i in 0 1 2 3 4 5; do
        write_if_exists /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq 500000
        write_if_exists /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2000000
    done
    for i in 6 7; do
        write_if_exists /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq 650000
        write_if_exists /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2600000
    done
}

set_cpu_limit() {
    local cluster="$1"
    local max_khz="$2"
    if [ -w /proc/ppm/policy/userlimit_max_cpu_freq ]; then
        echo "$cluster $max_khz" >/proc/ppm/policy/userlimit_max_cpu_freq 2>/dev/null
    fi
}

set_system_boost() {
    local enabled="$1"
    if [ -w /proc/ppm/policy_status ]; then
        echo "9 $enabled" >/proc/ppm/policy_status 2>/dev/null
    fi
}

apply_display_tuning() {
    # 1. Thermal HAL baseline injection
    for type in CPU GPU SKIN SOC NPU TPU POWER_AMPLIFIER BATTERY; do
        cmd thermalservice inject-temperature $type NONE $type 35.0 2>/dev/null
    done
    cmd thermalservice inject-temperature SKIN NONE shell_skin 35.0 2>/dev/null
    cmd thermalservice override-status 0 2>/dev/null

    # 2. Disable Android 15 display clampers (stops low-power, low-light, and app 60Hz downclocking)
    device_config put display_manager com.android.server.display.feature.flags.enable_vsync_low_power_vote false 2>/dev/null
    device_config put display_manager com.android.server.display.feature.flags.enable_vsync_low_light_vote false 2>/dev/null
    device_config put display_manager com.android.server.display.feature.flags.enable_power_throttling_clamper false 2>/dev/null
    device_config put display_manager com.android.server.display.feature.flags.ignore_app_preferred_refresh_rate_request true 2>/dev/null
    device_config put display_manager com.android.server.display.feature.flags.enable_synthetic_60hz_modes false 2>/dev/null

    # 3. MediaTek MT6877 / Dimensity 7050 hardware FPSGO & FBT nodes
    write_if_exists /sys/kernel/fpsgo/common/fpsgo_enable 1
    write_if_exists /sys/kernel/fpsgo/fbt/boost_ta 1
    write_if_exists /sys/kernel/fpsgo/fbt/boost_VIP 1
    write_if_exists /sys/kernel/fpsgo/fbt/rescue_enable 1
    write_if_exists /sys/kernel/fpsgo/fbt/ultra_rescue 1
    write_if_exists /sys/kernel/fpsgo/fbt/engine_cooler_enable 0
    write_if_exists /sys/kernel/fpsgo/composer/control_hwui 1
    write_if_exists /sys/kernel/fpsgo/fbt/limit_cfreq 0
    write_if_exists /sys/kernel/fpsgo/fbt/limit_rfreq 0

    # 4. ColorOS / Realme UI permanent 120Hz locks
    settings put secure oplus_customize_screen_refresh_rate 2 2>/dev/null
    settings put system oplus_customize_screen_refresh_rate 2 2>/dev/null
    settings put system min_refresh_rate 120.0 2>/dev/null
    settings put system peak_refresh_rate 120.0 2>/dev/null
    settings put global min_refresh_rate 120.0 2>/dev/null
    settings put global peak_refresh_rate 120.0 2>/dev/null
    settings put system power_save_screen_refresh_rate 2 2>/dev/null
    settings put system user_refresh_rate 120 2>/dev/null
    settings put global customized_refresh_rate 120 2>/dev/null
    settings put system oplus_high_performance_mode 1 2>/dev/null
    settings put system sys_force_60Hz 0 2>/dev/null
    settings put secure sys_force_60Hz 0 2>/dev/null
    settings put global sys_force_60Hz 0 2>/dev/null
    settings put secure match_content_frame_rate_user_preference 0 2>/dev/null

    # 5. Fluid native animation physics
    settings put global window_animation_scale 1.0 2>/dev/null
    settings put global transition_animation_scale 1.0 2>/dev/null
    settings put global animator_duration_scale 1.0 2>/dev/null
    settings put system setting_app_startup_anim_speed "fast" 2>/dev/null
    settings put system is_oplus_launcher_zoom 0 2>/dev/null
    settings put secure is_oplus_launcher_zoom 0 2>/dev/null
}

set_schedutil_response() {
    local profile="$1"
    local up=80
    local down=15000

    case "$profile" in
        boost)
            up=50
            down=20000
            ;;
        battery)
            up=800
            down=40000
            ;;
        thermal)
            up=300
            down=25000
            ;;
        balanced|*)
            up=80
            down=15000
            ;;
    esac

    for gov in /sys/devices/system/cpu/cpufreq/sugov_ext /sys/devices/system/cpu/cpu*/cpufreq/schedutil; do
        [ -d "$gov" ] || continue
        write_if_exists "$gov/up_rate_limit_us" "$up"
        write_if_exists "$gov/down_rate_limit_us" "$down"
        if [ -f "$gov/iowait_boost_enabled" ]; then
            write_if_exists "$gov/iowait_boost_enabled" 1
        fi
    done
}

enable_mglru() {
    if [ -f /sys/kernel/mm/lru_gen/enabled ]; then
        current="$(cat /sys/kernel/mm/lru_gen/enabled 2>/dev/null)"
        case "$current" in
            *7*|*0x0007*) ;;
            *) echo 7 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null ;;
        esac
    fi
}

apply_memory_balance() {
    local profile="${1:-balanced}"
    local swappiness=35
    local cache_pressure=50
    local dirty_ratio=15
    local dirty_background=4
    local dirty_writeback=1500
    local dirty_expire=3000
    local page_cluster=0
    local compaction=10
    local watermark=200

    case "$profile" in
        boost)
            swappiness=30
            cache_pressure=40
            dirty_ratio=12
            dirty_background=3
            dirty_writeback=1200
            compaction=5
            watermark=200
            ;;
        battery)
            swappiness=50
            cache_pressure=70
            dirty_ratio=10
            dirty_background=3
            dirty_writeback=2000
            compaction=20
            watermark=150
            ;;
        thermal)
            swappiness=40
            cache_pressure=60
            dirty_ratio=12
            dirty_background=4
            dirty_writeback=1500
            compaction=15
            watermark=150
            ;;
    esac

    enable_mglru
    write_if_exists /proc/sys/vm/swappiness "$swappiness"
    write_if_exists /proc/sys/vm/vfs_cache_pressure "$cache_pressure"
    write_if_exists /proc/sys/vm/dirty_ratio "$dirty_ratio"
    write_if_exists /proc/sys/vm/dirty_background_ratio "$dirty_background"
    write_if_exists /proc/sys/vm/dirty_writeback_centisecs "$dirty_writeback"
    write_if_exists /proc/sys/vm/dirty_expire_centisecs "$dirty_expire"
    write_if_exists /proc/sys/vm/page-cluster "$page_cluster"
    write_if_exists /proc/sys/vm/compaction_proactiveness "$compaction"
    write_if_exists /proc/sys/vm/watermark_scale_factor "$watermark"
}

apply_storage_tuning() {
    for queue in /sys/block/dm-*/queue /sys/block/mmcblk*/queue /sys/block/sd*/queue /sys/block/sda/queue /sys/block/sdb/queue; do
        [ -d "$queue" ] || continue
        if [ -f "$queue/scheduler" ]; then
            sched="$(cat "$queue/scheduler" 2>/dev/null)"
            case "$sched" in
                *mq-deadline*) echo mq-deadline >"$queue/scheduler" 2>/dev/null ;;
                *none*) ;;
            esac
        fi
        write_if_exists "$queue/read_ahead_kb" 128
        write_if_exists "$queue/rq_affinity" 1
    done
}

apply_runtime_props() {
    device_config put activity_manager_native_boot use_freezer true 2>/dev/null
    resetprop -p persist.vendor.mtk.perf_turbo 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.enable 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.v2.enable 1 2>/dev/null
    resetprop -p persist.vendor.mtk.fpsgo.v3.enable 1 2>/dev/null
    resetprop -p debug.vendor.perf.smart_touch 1 2>/dev/null
    resetprop -p vendor.boostfwk.frame.decision 2 2>/dev/null
    resetprop -p persist.sys.boot.logcat 0 2>/dev/null
    resetprop -p logd.log_size 64K 2>/dev/null
    resetprop -p persist.logd.size 64K 2>/dev/null
    apply_display_tuning
}

clear_stale_props() {
    for prop in \
        persist.sys.sugov.up_rate_limit_us \
        persist.sys.sugov.down_rate_limit_us \
        persist.sys.media.priority \
        persist.sys.io.latency \
        persist.sys.io.no_merges \
        persist.sys.min_refresh_rate \
        persist.sys.peak_refresh_rate \
        persist.sys.composition.type \
        persist.sys.force_highend_gfx \
        persist.vendor.mtk.ged.smart_boost \
        persist.vendor.mtk.ged.boost_enable
    do
        delete_prop_if_possible "$prop"
    done

    resetprop -n debug.sf.disable_backpressure 0 2>/dev/null
    resetprop -n debug.sf.latch_unsignaled 0 2>/dev/null
}

apply_video_boost() {
    clear_cpu_limits
    set_system_boost 1
    set_schedutil_response boost
    apply_memory_balance boost
    apply_display_tuning
    write_power_mode "video_boost"
}

apply_battery_guard() {
    set_system_boost 0
    set_cpu_limit 0 1200000
    set_cpu_limit 1 1400000
    set_schedutil_response battery
    apply_memory_balance battery
    write_power_mode "screen_off"
}

apply_thermal_policy() {
    local state="$1"
    set_system_boost 0
    case "$state" in
        critical)
            set_cpu_limit 0 1400000
            set_cpu_limit 1 1700000
            set_schedutil_response thermal
            apply_memory_balance thermal
            log_thermal "critical thermal throttling applied"
            ;;
        elevated)
            set_cpu_limit 0 1600000
            set_cpu_limit 1 2000000
            set_schedutil_response thermal
            apply_memory_balance thermal
            log_thermal "elevated thermal throttling applied"
            ;;
        warm)
            set_cpu_limit 0 1800000
            set_cpu_limit 1 2200000
            set_schedutil_response balanced
            apply_memory_balance balanced
            log_thermal "warm thermal soft cap applied"
            ;;
        normal|*)
            clear_cpu_limits
            set_schedutil_response balanced
            apply_memory_balance balanced
            apply_display_tuning
            log_thermal "restored normal thermal limits"
            ;;
    esac
}

restore_normal_limits() {
    clear_cpu_limits
    set_system_boost 0
    set_schedutil_response balanced
    apply_memory_balance balanced
    apply_display_tuning
    write_power_mode "normal"
}

calculate_thermal_state() {
    refresh_thermal_cache
    if [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_CRITICAL_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge "$BATTERY_CRITICAL_MAX" ]; then
        echo "critical"
    elif [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_ELEVATED_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge "$BATTERY_ELEVATED_MAX" ]; then
        echo "elevated"
    elif [ "$CAREFUL_CPU_TEMP" -ge "$THERMAL_NORMAL_MAX" ] || [ "$CAREFUL_BATTERY_TEMP" -ge "$BATTERY_WARM_MAX" ]; then
        echo "warm"
    else
        echo "normal"
    fi
}

detect_power_mode() {
    if ! screen_is_on; then
        echo "screen_off"
        return 0
    fi

    state="$(calculate_thermal_state)"
    current="$(read_power_mode)"

    if [ "$current" = "thermal_guard" ]; then
        if [ "$CAREFUL_CPU_TEMP" -le "$THERMAL_RECOVERY_TARGET" ] && [ "$CAREFUL_BATTERY_TEMP" -le "$BATTERY_RECOVERY_TARGET" ]; then
            echo "normal"
        else
            echo "thermal_guard"
        fi
        return 0
    fi

    case "$state" in
        critical|elevated)
            echo "thermal_guard"
            ;;
        *)
            if is_heavy_app && [ "$CAREFUL_CPU_TEMP" -lt "$THERMAL_ELEVATED_MAX" ] && [ "$CAREFUL_BATTERY_TEMP" -lt "$BATTERY_ELEVATED_MAX" ]; then
                echo "video_boost"
            else
                echo "normal"
            fi
            ;;
    esac
}

choose_monitor_interval() {
    if ! screen_is_on; then
        echo 120
    elif is_heavy_app; then
        echo 30
    else
        echo 45
    fi
}

list_wpa_supplicant() {
    ps -A -o USER,PID,NAME,ARGS 2>/dev/null | grep '[w]pa_supplicant' || true
}

cleanup_rogue_wpa_supplicant() {
    [ "$(getprop persist.careful.allow_termux_wpa)" = "1" ] && return 0
    ps -A -o USER,PID,NAME,ARGS 2>/dev/null | awk '/wpa_supplicant/ && $1 ~ /^u0_a/ {print $2}' | while read -r pid; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done
}
