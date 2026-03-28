#!/system/bin/sh
# Careful Unified Optimizer v4.0 - early boot tuning

LOG_TAG="CarefulUnifiedOpt"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

apply_early_governor_tuning() {
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

apply_early_memory_tuning() {
    if [ -f /sys/kernel/mm/lru_gen/enabled ]; then
        echo 7 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null || \
        echo 3 >/sys/kernel/mm/lru_gen/enabled 2>/dev/null
    fi

    write_if_exists /proc/sys/vm/max_map_count 262144
    write_if_exists /proc/sys/fs/file-max 1024000
    write_if_exists /proc/sys/fs/inotify/max_user_watches 262144
    write_if_exists /proc/sys/fs/inotify/max_user_instances 8192

    # Keep THP conservative on Android to avoid reclaim and writeback churn.
    write_if_exists /sys/kernel/mm/transparent_hugepage/enabled never
    write_if_exists /sys/kernel/mm/transparent_hugepage/defrag madvise
}

mkdir -p /sdcard/Android/HChai/HC_memory 2>/dev/null
touch /sdcard/Android/HChai/HC_memory/Run.log 2>/dev/null

apply_early_memory_tuning
apply_early_governor_tuning

log -t "$LOG_TAG" "v4 early boot tuning applied"
