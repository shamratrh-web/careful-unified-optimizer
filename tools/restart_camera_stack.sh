#!/system/bin/sh
# Safely restart the camera stack when it is unhealthy.

LOG_TAG="CarefulUnifiedOpt"
TOOLSDIR="${0%/*}"
MODDIR="${TOOLSDIR%/*}"

active_clients() {
    dumpsys media.camera 2>/dev/null | awk '
        /Active Camera Clients:/ { getline; print; exit }
    '
}

current_clients="$(active_clients)"
case "$current_clients" in
    ''|'[]') ;;
    *)
        printf '%s\n' "Camera is in use; close camera apps before restarting the stack."
        exit 1
        ;;
esac

before="$(ps -A -o PID,NAME 2>/dev/null | grep -E 'cameraserver|camerahalserver')"
printf 'Before:\n%s\n' "$before"

setprop ctl.restart cameraserver 2>/dev/null
setprop ctl.restart camerahalserver 2>/dev/null

tries=0
while [ "$tries" -lt 15 ]; do
    sleep 1
    state_server="$(getprop init.svc.cameraserver)"
    state_hal="$(getprop init.svc.camerahalserver)"
    if [ "$state_server" = "running" ] && [ "$state_hal" = "running" ]; then
        break
    fi
    tries=$((tries + 1))
done

after="$(ps -A -o PID,NAME 2>/dev/null | grep -E 'cameraserver|camerahalserver')"
log -t "$LOG_TAG" "Camera stack restart requested"
printf '\nAfter:\n%s\n' "$after"
