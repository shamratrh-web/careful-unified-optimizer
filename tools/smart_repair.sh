#!/system/bin/sh
# Manual maintenance flow used by the Magisk action button.

set -u

LOG_TAG="CarefulUnifiedOpt"
TOOLSDIR="${0%/*}"
MODDIR="${TOOLSDIR%/*}"
OUTDIR="/sdcard/Download"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUTDIR/careful_optimizer_action_$STAMP.txt"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

mkdir -p "$OUTDIR" 2>/dev/null
: >"$REPORT"

note() {
    printf '%s\n' "$1" | tee -a "$REPORT"
    log -t "$LOG_TAG" "$1"
}

note "Careful Unified Optimizer action started"
note "Mode before: $(read_power_mode)"
note "Temps before: cpu=$(get_cpu_temp) shell=$(get_shell_temp) battery=$(get_battery_temp)"

QUIET=1 sh "$MODDIR/tools/fix_wpa_supplicant.sh" >>"$REPORT" 2>&1
note "Wi-Fi supplicant cleanup completed"

if ! dumpsys media.camera >/dev/null 2>&1; then
    sh "$MODDIR/tools/restart_camera_stack.sh" >>"$REPORT" 2>&1
    note "Camera stack restart was required"
else
    note "Camera stack looks alive; restart skipped"
fi

sh "$MODDIR/smart_balance.sh" manual >>"$REPORT" 2>&1
note "Smart balance reapplied"

snapshot_path="$(sh "$MODDIR/tools/collect_health_snapshot.sh" 2>>"$REPORT" | tail -n 1)"
note "Health snapshot: $snapshot_path"
note "Action report: $REPORT"

printf '%s\n' "$REPORT"
