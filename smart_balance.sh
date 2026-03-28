#!/system/bin/sh
# Careful Unified Optimizer v4.0 - live balance profile

LOG_TAG="CarefulSmartBalance"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

apply_governor_balance() {
    if [ -d /sys/devices/system/cpu/cpufreq/sugov_ext ]; then
        write_if_exists /sys/devices/system/cpu/cpufreq/sugov_ext/up_rate_limit_us 300
        write_if_exists /sys/devices/system/cpu/cpufreq/sugov_ext/down_rate_limit_us 15000
    fi

    for gov in /sys/devices/system/cpu/cpufreq/policy*/schedutil \
               /sys/devices/system/cpu/cpu*/cpufreq/schedutil; do
        [ -d "$gov" ] || continue
        write_if_exists "$gov/up_rate_limit_us" 300
        write_if_exists "$gov/down_rate_limit_us" 15000
        write_if_exists "$gov/iowait_boost_enabled" 1
    done
}

apply_memory_balance() {
    if [ -f /sys/kernel/mm/lru_gen/enabled ]; then
        echo 7 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null || \
        echo 3 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null
    fi

    write_if_exists /proc/sys/vm/swappiness 80
    write_if_exists /proc/sys/vm/vfs_cache_pressure 70
    write_if_exists /proc/sys/vm/dirty_ratio 16
    write_if_exists /proc/sys/vm/dirty_background_ratio 4
    write_if_exists /proc/sys/vm/compaction_proactiveness 30
    write_if_exists /proc/sys/vm/watermark_scale_factor 18
    write_if_exists /proc/sys/vm/page-cluster 0
}

if [ "$(getprop sys.boot_completed)" != "1" ]; then
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 2
    done
fi

apply_memory_balance
apply_governor_balance

for prop in \
    persist.sys.composition.type \
    persist.sys.force_highend_gfx \
    persist.sys.use_dithering \
    persist.sys.ui.hw \
    persist.sys.powermode; do
    resetprop -p -d "$prop" 2>/dev/null
done

for prop in \
    debug.sf.vsync_reinject_ignore \
    logcat.live \
    wifi.supplicant_scan_interval \
    pm.sleep_mode; do
    resetprop -d "$prop" 2>/dev/null
done

resetprop persist.sys.smart_ram_management 1 2>/dev/null
resetprop cached_apps_freezer disabled 2>/dev/null
resetprop persist.sys.cached_apps_freezer disabled 2>/dev/null
resetprop -p persist.sys.boot.logcat 0 2>/dev/null

log -t "$LOG_TAG" "v4 live balance applied"
