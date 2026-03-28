#!/system/bin/sh
# Apply the screen-off battery guard manually.

LOG_TAG="CarefulUnifiedOpt"
TOOLSDIR="${0%/*}"
MODDIR="${TOOLSDIR%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

apply_battery_guard
log -t "$LOG_TAG" "Manual battery guard applied"
printf '%s\n' "Applied screen-off battery guard"
