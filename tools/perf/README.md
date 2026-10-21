# Measuring and comparing (developers)

Everything here runs in the nested test session of `tools/nested` (own Hyprland, own D-Bus, own HOME, one virtual 2560x1600 monitor that is captured
directly): your own desktop is not touched and no workspace is switched. Nothing is written into the repository; results and pictures go to `$NB`
(default `/tmp/widgetdeck-perf`, `/tmp/widgetdeck-vr`). Test data only: curl is replaced by a stub that replays recorded answers of a made-up location,
the Wi-Fi name is invented, the music player is a mock, the widgets use their own demo switches.

| Script | What it does |
|---|---|
| `up.sh [--monitors 2]` | brings the session into the defined state (monitor, wallpapers, stubs, bar and notifications on, mock player) |
| `baseline.sh <label> [--quick] [--monitors 2] [--modes "frosted liquid"]` | the measuring run: cold start, memory after the start and after 10 minutes (RSS / PSS / GPU memory), idle CPU, wakeups, GPU time, process starts, hover, size animations, music, network requests per hour, cache and log |
| `report.py <run> [<run after the change>]` | the table (one run, or two runs side by side with the change in percent) |
| `sample.py` | the sampler behind it (reads `/proc`, DRM `fdinfo`; Python standard library only) |
| `perwidget.sh <label>` | one widget at a time (plus the bar alone): what each one costs |
| `frames.sh record <dir>` / `compare <a> <b>` | animations: exact size timelines of the Small / Large change (checked strictly) and frame series of music, turntable, hover (informational) |
| `../visual-regression.sh baseline <dir>` / `check <dir>` | pixel comparison of about 60 states (all widgets small / large, Frosted / Liquid, three wallpapers, weather icons, Formula 1, turntable, bar, power panel, notification, builder, glass presets) with an automatically measured mask of the moving parts |

Not installed here, but better when available (official repositories): `strace` (`strace -c -f` counts every `exec`), `perf`, `sysstat` (`pidstat`),
`powertop`, `intel-gpu-tools` (`intel_gpu_top`). Without them the sampler uses `/proc` (context switches as wakeups, a 10 ms scan for new child processes
as process starts = a lower bound, the DRM `fdinfo` render-engine time as GPU time).
