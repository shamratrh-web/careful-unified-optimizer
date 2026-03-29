#!/system/bin/sh
# Careful Unified Optimizer v6.0 ThermalGuard Pro - Early Boot
# Minimal early-boot initialization

MODDIR="${0%/*}"
LOG_TAG="CarefulThermalGuard"

# Source common utilities
[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

# Apply system properties early
if [ -f "$MODDIR/system.prop" ]; then
    resetprop -p --file "$MODDIR/system.prop" 2>/dev/null
fi

# Minimal early initialization
# Full thermal management starts in service.sh after boot

log -t "$LOG_TAG" "v6.0 early boot initialized"
exit 0
