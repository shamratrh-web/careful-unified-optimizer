#!/system/bin/sh
# Careful Unified Optimizer v6.3 Ultimate Smoothness - Late Boot

LOG_TAG="CarefulSmoothness"
MODDIR="${0%/*}"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

# Initialize
[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" boot

# Fast Adaptive Monitoring Loop - 15s for Reels & Game Detection
(
  while true; do
    sleep 15
    [ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" auto
  done
) &

log -t "$LOG_TAG" "v6.3 Ultimate Smoothness service started"
exit 0
