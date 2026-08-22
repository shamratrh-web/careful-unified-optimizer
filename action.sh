#!/system/bin/sh
# Magisk Action Button Entrypoint - Careful Unified Optimizer v6.9
MODDIR="${0%/*}"

echo "======================================================"
echo "   ⚡ CAREFUL UNIFIED OPTIMIZER - MANUAL TRIGGER"
echo "======================================================"

echo "[1/3] Applying hardware CPU, 120Hz display & governor tuning..."
sh "$MODDIR/smart_balance.sh" manual

echo "[2/3] Executing full AOT machine-code app optimization..."
sh "$MODDIR/tools/nightly_optimizer.sh" force

echo "[3/3] Compacting ZRAM & trimming UFS storage..."
fstrim -v /data 2>/dev/null || true

echo "======================================================"
echo "   ✅ ALL APPS & SYSTEM FULLY OPTIMIZED!"
echo "======================================================"
exit 0
