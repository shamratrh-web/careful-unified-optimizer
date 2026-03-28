#!/system/bin/sh
# Careful Unified Optimizer v4.0 - late boot tuning

LOG_TAG="CarefulUnifiedOpt"
MODDIR="/data/adb/modules/careful_optimization"

write_if_exists() {
    [ -e "$1" ] || return 0
    echo "$2" >"$1" 2>/dev/null
}

apply_live_props_and_mounts() {
    for mod_path in /data/adb/modules/*; do
        [ -d "$mod_path" ] || continue
        [ -f "$mod_path/disable" ] && continue
        [ -f "$mod_path/remove" ] && continue

        [ -f "$mod_path/system.prop" ] && resetprop -p --file "$mod_path/system.prop"

        find "$mod_path/system" "$mod_path/vendor" -type f 2>/dev/null | while read -r mod_file; do
            rel="${mod_file#$mod_path/}"
            target="/$rel"
            [ -f "$target" ] || target="/system/$rel"
            if [ -f "$target" ]; then
                chcon --reference="$target" "$mod_file" 2>/dev/null
                mount -o bind "$mod_file" "$target" 2>/dev/null
            fi
        done
    done
}

apply_storage_tuning() {
    for queue in /sys/block/dm-*/queue /sys/block/sd*/queue /sys/block/mmcblk*/queue; do
        [ -f "$queue/scheduler" ] || continue
        sched=$(cat "$queue/scheduler" 2>/dev/null)
        case "$sched" in
            *mq-deadline*) echo mq-deadline >"$queue/scheduler" 2>/dev/null ;;
            *none*) ;;
        esac
    done
}

cleanup_rogue_wpa_supplicant() {
    # Keep the vendor-managed supplicant. Kill only rogue Termux-launched
    # supplicant processes that fight over wlan0 and have been linked to the
    # observed tombstones.
    [ "$(getprop persist.careful.allow_termux_wpa)" = "1" ] && return 0

    for proc in /proc/[0-9]*; do
        [ -r "$proc/cmdline" ] || continue
        pid="${proc#/proc/}"
        cmdline="$(tr '\000' ' ' <"$proc/cmdline" 2>/dev/null)"

        case "$cmdline" in
            *"/vendor/bin/hw/wpa_supplicant"*) continue ;;
            *"wpa_supplicant"*"/data/data/com.termux/files/usr/tmp/"*)
                log -t "$LOG_TAG" "Killing rogue wpa_supplicant pid=$pid"
                kill "$pid" 2>/dev/null
                sleep 1
                kill -9 "$pid" 2>/dev/null
                ;;
        esac
    done
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

cleanup_rogue_wpa_supplicant
[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh"

# Trade a bit less writeback churn for lower background battery cost.
write_if_exists /proc/sys/vm/dirty_writeback_centisecs 1500
write_if_exists /proc/sys/vm/dirty_expire_centisecs 3000
apply_storage_tuning

# Let late vendor services settle, then apply our balanced profile once more.
sleep 45
cleanup_rogue_wpa_supplicant
[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh"
write_if_exists /proc/sys/vm/dirty_writeback_centisecs 1500
write_if_exists /proc/sys/vm/dirty_expire_centisecs 3000
apply_storage_tuning

mkdir -p /sdcard/Android/HChai/HC_memory 2>/dev/null
touch /sdcard/Android/HChai/HC_memory/Run.log 2>/dev/null

# Preserve live-load support, but keep the watcher opt-in so the module does
# not wake itself forever on a battery-focused profile.
if [ "$(getprop persist.careful.live_module_watch)" = "1" ]; then
    (
        previous_list="$(ls -1 /data/adb/modules 2>/dev/null)"
        while true; do
            sleep 120
            current_list="$(ls -1 /data/adb/modules 2>/dev/null)"
            [ "$current_list" = "$previous_list" ] && continue
            log -t "$LOG_TAG" "Module change detected; applying live props and mounts"
            apply_live_props_and_mounts
            previous_list="$current_list"
        done
    ) &
fi

# Low-cost guard against rogue Termux supplicant processes returning later.
(
    while true; do
        sleep 180
        cleanup_rogue_wpa_supplicant
    done
) &

log -t "$LOG_TAG" "v4 late boot tuning applied"
exit 0
