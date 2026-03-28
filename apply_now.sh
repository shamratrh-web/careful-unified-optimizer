#!/system/bin/sh
# Manual live apply helper for Careful Unified Optimizer v5.0

LOG_TAG="CarefulUnifiedOpt"
MODDIR="${0%/*}"

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

[ -f "$MODDIR/smart_balance.sh" ] && sh "$MODDIR/smart_balance.sh" manual
apply_live_props_and_mounts

log -t "$LOG_TAG" "Manual live apply completed"
