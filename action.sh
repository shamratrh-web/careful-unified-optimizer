#!/system/bin/sh
# Magisk action entrypoint for Careful Unified Optimizer v6.5

MODDIR="${0%/*}"

exec sh "$MODDIR/tools/smart_repair.sh"
