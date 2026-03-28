#!/system/bin/sh
# Simple two-phase proof workflow for reels smoothness and battery draw.
# Usage:
#   su -c sh /data/adb/modules/careful_optimization/tools/reels_ab_proof.sh prep
#   ...use Instagram/Facebook/YouTube reels for 10-15 minutes...
#   su -c sh /data/adb/modules/careful_optimization/tools/reels_ab_proof.sh report

set -u

OUTDIR="/sdcard/Download"
mkdir -p "$OUTDIR" 2>/dev/null

PACKAGES="com.instagram.android com.facebook.katana com.google.android.youtube"

prep() {
    dumpsys batterystats --reset >/dev/null 2>&1
    for pkg in $PACKAGES; do
        dumpsys gfxinfo "$pkg" reset >/dev/null 2>&1
    done
    printf "Prepared batterystats and gfxinfo counters. Use reels for 10-15 minutes, then run: report\n"
}

report() {
    STAMP="$(date +%Y%m%d-%H%M%S)"
    OUTFILE="$OUTDIR/reels_ab_report_$STAMP.txt"
    : >"$OUTFILE"

    {
        echo "==== Batterystats Summary ===="
        dumpsys batterystats | sed -n '/Estimated power use (mAh):/,+60p'
        echo
        echo "==== Thermal Summary ===="
        dumpsys thermalservice | sed -n '1,120p'
        echo
        for pkg in $PACKAGES; do
            echo "==== gfxinfo $pkg ===="
            dumpsys gfxinfo "$pkg" framestats 2>/dev/null | sed -n '1,220p'
            echo
        done
    } >>"$OUTFILE" 2>&1

    printf '%s\n' "$OUTFILE"
}

case "${1:-}" in
    prep) prep ;;
    report) report ;;
    *)
        echo "Usage: $0 prep|report"
        exit 1
        ;;
esac
