#!/system/bin/sh
# Collect a health snapshot for Careful Unified Optimizer.

set -u

OUTDIR="/sdcard/Download"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTFILE="$OUTDIR/careful_optimizer_health_$STAMP.txt"

mkdir -p "$OUTDIR" 2>/dev/null

write_section() {
    printf "\n==== %s ====\n" "$1" >>"$OUTFILE"
}

append_cmd() {
    printf "$ %s\n" "$1" >>"$OUTFILE"
    sh -c "$1" >>"$OUTFILE" 2>&1
}

: >"$OUTFILE"

write_section "Module"
append_cmd "sed -n '1,20p' /data/adb/modules/careful_optimization/module.prop"

write_section "Runtime Props"
append_cmd "resetprop | grep -E 'fpsgo|perf_turbo|smart_ram_management|boot.logcat|debug\\.sf.disable_backpressure|debug\\.sf.latch_unsignaled|force_highend_gfx|composition.type|powermode|logcat.live'"
append_cmd "dumpsys activity settings | sed -n '/CachedAppOptimizer settings/,+8p'"

write_section "Tunables"
append_cmd "for f in /proc/sys/vm/swappiness /proc/sys/vm/vfs_cache_pressure /proc/sys/vm/dirty_ratio /proc/sys/vm/dirty_background_ratio /proc/sys/vm/compaction_proactiveness /proc/sys/vm/watermark_scale_factor /proc/sys/vm/page-cluster /proc/sys/vm/dirty_writeback_centisecs /sys/kernel/mm/lru_gen/enabled /proc/ppm/policy/userlimit_max_cpu_freq /proc/ppm/policy/userlimit_min_cpu_freq /proc/ppm/policy/lcmoff_min_freq /proc/ppm/policy_status; do [ -e \"\$f\" ] && printf '\n--- %s ---\n' \"\$f\" && cat \"\$f\" 2>/dev/null; done"

write_section "Battery"
append_cmd "dumpsys battery | sed -n '1,120p'"
append_cmd "dumpsys batterystats --charged | sed -n '/Estimated power use (mAh):/,+80p'"

write_section "Thermal"
append_cmd "dumpsys thermalservice | sed -n '1,180p'"
append_cmd "for z in /sys/class/thermal/thermal_zone*; do [ -r \"\$z/type\" ] || continue; printf '%s %s %s\n' \"\$z\" \"\$(cat \$z/type 2>/dev/null)\" \"\$(cat \$z/temp 2>/dev/null)\"; done | sed -n '1,80p'"

write_section "Crash Summary"
append_cmd "ls -lht /data/tombstones 2>/dev/null | sed -n '1,20p'"
append_cmd "for f in /data/tombstones/tombstone_05 /data/tombstones/tombstone_04 /data/tombstones/tombstone_03; do [ -f \"\$f\" ] || continue; echo \"--- \$f ---\"; sed -n '1,120p' \"\$f\" | grep -E '^(Cmdline|Abort message|signal|pid:|uid:|process uptime|Build fingerprint|Cause)'; done"
append_cmd "ls -lht /data/anr 2>/dev/null | sed -n '1,20p'"
append_cmd "for f in /data/anr/anr_*; do [ -f \"\$f\" ] || continue; echo \"--- \$f ---\"; sed -n '1,80p' \"\$f\" | grep -E '^(Subject|Cmd line|Process:|PID:|Reason:|Load:|CPU usage|DALVIK THREADS|----- pid)' ; done | sed -n '1,120p'"
append_cmd "grep -i -n -E 'panic|watchdog|BUG:|Oops|Fatal|reboot reason' /sys/fs/pstore/console-ramoops-0 2>/dev/null | sed -n '1,120p'"

write_section "Camera"
append_cmd "getprop | grep -i -E 'camera.disable_zsl_mode|vendor.oplus.camera.60fps.performance|persist.vendor.camera3.pipeline.bufnum' | sed -n '1,80p'"
append_cmd "getprop | grep -E 'init\\.svc\\.(cameraserver|camerahalserver)'"
append_cmd "dumpsys media.camera | sed -n '1,120p'"

write_section "Processes"
append_cmd "ps -A -o PID,NAME,ARGS 2>/dev/null | grep -E 'facebook|instagram|youtube|wps|twitter|supplicant|surfaceflinger|thermal|camera' | grep -v grep | sed -n '1,120p'"

printf '%s\n' "$OUTFILE"
