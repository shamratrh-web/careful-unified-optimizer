#!/system/bin/sh
MODDIR="${0%/*}/.."
sh "$MODDIR/tools/nightly_optimizer.sh" force
