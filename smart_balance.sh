#!/system/bin/sh
# Careful Unified Optimizer v6.8 Ultimate Fluidity & KernelGuard live balance.

LOG_TAG="CarefulThermalGuard"
MODDIR="${0%/*}"

[ -f "$MODDIR/tools/common.sh" ] && . "$MODDIR/tools/common.sh"

target_mode="$1"
full_apply=0

case "$target_mode" in
    boot|manual)
        target_mode="$(detect_power_mode)"
        full_apply=1
        ;;
    auto|"")
        target_mode="$(detect_power_mode)"
        ;;
esac

if [ "$full_apply" = "1" ]; then
    clear_stale_props
    apply_runtime_props
    apply_storage_tuning
    apply_display_tuning
fi

current_mode="$(read_power_mode)"
if [ "$full_apply" = "1" ] || [ "$current_mode" != "$target_mode" ] || [ "$target_mode" = "video_boost" ]; then
    case "$target_mode" in
        screen_off)
            apply_battery_guard
            ;;
        thermal_guard)
            apply_thermal_policy "$(calculate_thermal_state)"
            write_power_mode "thermal_guard"
            ;;
        video_boost)
            apply_video_boost
            apply_display_tuning
            ;;
        *)
            restore_normal_limits
            apply_display_tuning
            ;;
    esac
fi

save_thermal_snapshot
refresh_thermal_cache
log_msg "v6.8 mode=$target_mode cpu=${CAREFUL_CPU_TEMP} shell=${CAREFUL_SHELL_TEMP} battery=${CAREFUL_BATTERY_TEMP}"
exit 0
