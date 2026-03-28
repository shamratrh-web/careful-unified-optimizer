#!/system/bin/sh
# Careful Unified Optimizer v5.0 - early boot tuning

LOG_TAG="CarefulUnifiedOpt"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
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
[ -f "$MODDIR/tools/common.sh" ] && restore_normal_limits >/dev/null 2>&1

log -t "$LOG_TAG" "v5 early boot tuning applied"
