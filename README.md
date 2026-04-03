# Careful Unified Optimizer v6.5 Balanced ThermalGuard

Balanced performance and battery tuning for MediaTek MT6877 / Dimensity 7050 devices on Android 15.

This release deliberately removes the aggressive v6.4 "micro-lag" hacks. On this device they were the wrong tradeoff:

- no forced 120 Hz refresh rate
- no permanent SurfaceFlinger backpressure override
- no global zero-latency governor settings
- no 10 second polling loop
- no queue `nomerges=2` forcing for all storage

Instead, v6.5 keeps the parts that fit the platform:

- cached app freezer enabled for Android 15
- moderate MGLRU and reclaim tuning
- adaptive PPM caps only when the device is hot or screen-off
- low-overhead service loop with heavier checks only when useful
- MediaTek vendor hints such as FPSGO and smart touch left available

## Device target

- SoC: MediaTek MT6877 / Dimensity 7050
- Android: 15 / API 35
- Verified on: realme RMX3741

## Profiles

- `normal`: uncapped CPU with balanced schedutil response
- `video_boost`: temporary vendor-friendly boost for reels / short-video style apps while cool
- `thermal_guard`: proportional CPU capping when CPU or battery temperatures rise
- `screen_off`: lower screen-off CPU limits for better idle drain

## Live install

To install this version over the active Magisk module without rebooting:

```sh
su -c sh /data/data/com.termux/files/home/careful_optimization/apply_now.sh
```

That syncs the repo into `/data/adb/modules/careful_optimization`, kills the old service loop, applies the new settings, and launches the new service.

## Monitoring

```sh
cat /data/adb/modules/careful_optimization/.power_mode
cat /data/adb/modules/careful_optimization/.thermal_history
logcat -s CarefulThermalGuard
```

## Optional properties

```properties
# Keep Termux-launched wpa_supplicant processes untouched
persist.careful.allow_termux_wpa=1
```

## Release notes

### v6.5

- replaces the aggressive v6.4 profile with a balanced Android 15 profile
- lowers reclaim pressure to reduce swap churn and `kswapd` activity
- keeps thermal control through PPM user limits instead of permanent boost hacks
- adds a real live installer that refreshes the running module without rebooting
- restores tool compatibility in `tools/common.sh`
