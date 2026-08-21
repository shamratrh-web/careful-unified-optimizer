#!/system/bin/sh
# Live installer and applier for Careful Unified Optimizer v6.6.

SRCMODDIR="${0%/*}"
LIVEMODDIR="/data/adb/modules/careful_optimization"
LOG_TAG="CarefulThermalGuard"

sync_live_module() {
    mkdir -p "$LIVEMODDIR/tools" 2>/dev/null

    for file in action.sh apply_now.sh module.prop post-fs-data.sh service.sh smart_balance.sh system.prop README.md; do
        [ -f "$SRCMODDIR/$file" ] && cp -af "$SRCMODDIR/$file" "$LIVEMODDIR/$file"
    done

    cp -af "$SRCMODDIR/tools/." "$LIVEMODDIR/tools/"

    chmod 0755 "$LIVEMODDIR"/action.sh \
        "$LIVEMODDIR"/apply_now.sh \
        "$LIVEMODDIR"/post-fs-data.sh \
        "$LIVEMODDIR"/service.sh \
        "$LIVEMODDIR"/smart_balance.sh \
        "$LIVEMODDIR"/tools/*.sh 2>/dev/null
}

restart_live_service() {
    pkill -f '/data/adb/modules/careful_optimization/service\.sh' 2>/dev/null || true
    pkill -f '/data/adb/modules/careful_optimization/smart_balance\.sh' 2>/dev/null || true
    sleep 1
    sh "$LIVEMODDIR/post-fs-data.sh" >/dev/null 2>&1
    sh "$LIVEMODDIR/smart_balance.sh" manual >/dev/null 2>&1
    sh "$LIVEMODDIR/service.sh" >/dev/null 2>&1 &
}

sync_live_module
restart_live_service

log -t "$LOG_TAG" "v6.6 live install applied from $SRCMODDIR"
printf '%s\n' "Applied v6.6 live to $LIVEMODDIR"
