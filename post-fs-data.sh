#!/system/bin/sh
# Careful Unified Optimizer v6.5 Balanced ThermalGuard early boot tuning.

MODDIR="${0%/*}"
LOG_TAG="CarefulThermalGuard"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

if [ -f "$MODDIR/system.prop" ]; then
    resetprop -p --file "$MODDIR/system.prop" 2>/dev/null
fi

clear_stale_props
enable_mglru
apply_memory_balance balanced
set_schedutil_response balanced
apply_display_tuning

log -t "$LOG_TAG" "v6.6 early boot tuning applied"
exit 0
