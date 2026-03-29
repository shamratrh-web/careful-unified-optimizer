#!/system/bin/sh
# Careful Unified Optimizer v6.4 Micro-Lag Eliminator - Late Boot

LOG_TAG="CarefulMicroLag"
MODDIR="${0%/*}"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

# Initialize
[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" boot

# Hyper-Fast Monitoring Loop - 10s for Stutter Elimination
(
  while true; do
    sleep 10
    [ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" auto
  done
) &

log -t "$LOG_TAG" "v6.4 Micro-Lag service started"
exit 0
