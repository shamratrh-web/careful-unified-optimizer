#!/system/bin/sh
# Clear module-owned PPM soft limits.

LOG_TAG="CarefulUnifiedOpt"
TOOLSDIR="${0%/*}"
MODDIR="${TOOLSDIR%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

restore_normal_limits
log -t "$LOG_TAG" "Manual PPM restore applied"
printf '%s\n' "Restored normal PPM limits"
