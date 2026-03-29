#!/system/bin/sh
# Careful Unified Optimizer v6.2 Gaming Pro - Late Boot

LOG_TAG="CarefulGamingPro"
MODDIR="${0%/*}"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

# Initialize
[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" boot

# Adaptive Monitoring Loop - 30s for quick Game Detection
(
  while true; do
    sleep 30
    [ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" auto
  done
) &

log -t "$LOG_TAG" "v6.2 Gaming Pro service started"
exit 0
