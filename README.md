Careful Unified Optimizer v5.0

What changed
- Drops the ineffective `sugov_ext` fight and uses real MediaTek PPM soft
  limits instead.
- Adds thermal-aware behavior so the module protects sustained smoothness when
  the phone is already hot instead of forcing short-lived boosts.
- Keeps the verified smoothness hooks for Instagram, Facebook, and YouTube
  reels without adding risky camera or thermal bypass props.
- Adds a Magisk `action.sh` path for one-tap repairs and health capture.

Files
- `post-fs-data.sh`: early boot RAM tuning and PPM reset
- `service.sh`: late boot tuning, Wi-Fi cleanup, and periodic auto-balance
- `smart_balance.sh`: apply the balanced profile based on thermal and screen
  state
- `action.sh`: Magisk action entrypoint for safe repairs
- `apply_now.sh`: re-apply module properties and bind mounts without reboot
- `tools/common.sh`: shared PPM, thermal, and repair helpers
- `tools/apply_battery_guard.sh`: apply the screen-off battery cap manually
- `tools/restore_normal_limits.sh`: clear module-owned PPM limits
- `tools/restart_camera_stack.sh`: safely restart camera services when needed
- `tools/smart_repair.sh`: manual maintenance flow used by the Magisk action

Useful commands
- `su -c sh /data/adb/modules/careful_optimization/smart_balance.sh`
- `su -c sh /data/adb/modules/careful_optimization/apply_now.sh`
- `su -c setprop persist.careful.live_module_watch 1`
- `su -c sh /data/adb/modules/careful_optimization/action.sh`
- `su -c sh /data/adb/modules/careful_optimization/tools/collect_health_snapshot.sh`
- `su -c sh /data/adb/modules/careful_optimization/tools/reels_ab_proof.sh prep`
- `su -c sh /data/adb/modules/careful_optimization/tools/reels_ab_proof.sh report`
- `su -c sh /data/adb/modules/careful_optimization/tools/fix_wpa_supplicant.sh`
- `su -c sh /data/adb/modules/careful_optimization/tools/restart_camera_stack.sh`
- `su -c sh /data/adb/modules/careful_optimization/tools/apply_battery_guard.sh`
- `su -c sh /data/adb/modules/careful_optimization/tools/restore_normal_limits.sh`

Notes
- Android's real cached-app freezer is already `use_freezer=false` on this
  ROM, so the old freezer props were redundant and have been removed.
- The module uses `userlimit_max_cpu_freq` for soft caps and leaves hard PPM
  overrides alone by default.
- `persist.careful.use_lcmoff_policy=1` is available as an opt-in experiment
  if you want to also enable the screen-off `LCM_OFF` policy later.
- The `tools/` scripts are there to produce evidence before changing tuning
  again. They are more useful than stacking extra placebo props.
- The module now kills rogue Termux-launched `wpa_supplicant` instances by
  default because they can conflict with the vendor Wi-Fi service on `wlan0`.
- If you intentionally need those Termux Wi-Fi workflows later, set
  `persist.careful.allow_termux_wpa=1`.
- The camera path is recovery-only by default because the live device does not
  show a clean camera HAL crash or a safe vendor prop override to force.
