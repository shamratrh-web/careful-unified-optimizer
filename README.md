Careful Unified Optimizer v4.0

What changed
- Fixes the CPU governor path for this device family by tuning `sugov_ext`.
- Keeps the helpful MediaTek FPSGO and app-freezer adjustments for smoother
  Instagram, Facebook, and YouTube short-video scrolling.
- Removes several stale or high-overhead properties that either do nothing on
  modern Android or can waste battery.
- Keeps live-load support available, but disables the forever watcher by
  default to avoid background wakeups.

Files
- `post-fs-data.sh`: early boot RAM and governor tuning
- `service.sh`: late boot tuning and optional live module watcher
- `smart_balance.sh`: apply the balanced profile live
- `apply_now.sh`: re-apply module properties and bind mounts without reboot

Useful commands
- `su -c sh /data/adb/modules/careful_optimization/smart_balance.sh`
- `su -c sh /data/adb/modules/careful_optimization/apply_now.sh`
- `su -c setprop persist.careful.live_module_watch 1`

Notes
- The live module watcher is now opt-in for battery reasons.
- This module does not blanket-whitelist Instagram, Facebook, or YouTube from
  Doze because that would hurt standby battery more than it helps foreground
  smoothness.
