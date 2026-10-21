# Contributing

Thanks for helping! Bug reports and small fixes are the most useful things right now.

* **Bugs:** open an issue with the template and paste the output of `widgetdeck-doctor` (it hides your home directory and prints no location or wallpaper path).
* **Pull requests:** keep them small and focused. Run the checks before you push:
  ```bash
  shellcheck -x -S warning install.sh update.sh uninstall.sh lib/*.sh bin/* qml/core/*.sh qml/widgets/sysmon/*.sh qml/modules/*.sh tools/*.sh tools/f1/*.sh tools/nested/*.sh
  python3 tools/check-i18n.py        # every UI text needs an English source and a German entry
  node tools/snapengine-test.js      # grid / snapping tests
  node tools/timetable-test.js       # timetable logic
  node tools/weathercard-test.js     # weather card logic (needs network for one check, skipped without)
  node tools/f1-test.js              # Formula 1 model (sessions, states, DST), re-runs itself under four time zones
  python3 tools/f1-helper-test.py    # Formula 1 data helper against a local mock server (cache, 429, offline, request counts)
  node tools/monitors-test.js        # monitor keys, moving widgets between monitors, wallpaper per output
  tools/untis-test.sh                # Untis client against a local mock server (invented data)
  tools/secret-scan.sh               # no personal paths, tokens or coordinates
  ```
  The same checks run on GitHub for every pull request (they only check, nothing is deployed).
* **Texts:** English is the source language. In QML use `I18n.tr("English text")`, in shell scripts `t 'English text %s' arg`. German goes into `qml/core/i18n.js` and `lib/i18n.sh`. More languages: add a table next to `de`.
* **Another style for a widget** (see the music widget): add a choice option `skin` to the widget in `qml/widgets/Registry.js` (options that only apply to one style get `when: { key: "skin", is: "<value>" }`, per-style sizes go into `skinSizes`), put the new look into its own file next to the widget (`qml/widgets/<name>/<Skin>View.qml`, state and logic stay in the widget and are passed in as `host`), and let the widget crossfade between the views with a `Loader` that is only active while its style is selected. Add the new texts to `qml/core/i18n.js` and run the checks above.
* **A new weather icon** (see the weather card): describe it in `tools/blender/icon_scenes.py` (a variant = layers of soft metaball parts, plus a material from `MATERIALS`) and render it with `tools/blender/render.sh --only <variant>` (needs Blender: `pacman -S blender`; frames land in `qml/widgets/weathercard/icons3d/`). Then list the same layers in `VARIANTS` in `qml/widgets/weathercard/Model.js` (and give new layers their motion in `LAYER_HINTS`), and for a new weather kind add its WMO codes in `kindOf()`. `node tools/weathercard-test.js` checks that the scenes, the widget and the rendered frames agree.
* **A new widget: size table and glass:** add one entry to `TYPES` in `qml/widgets/Registry.js` (`file`, a default `size`, the **size table** `sizes: { small: [w, h], large: [w, h] }` that drives the Small / Large buttons and the per-monitor default size, and `props` for the settings panel). `WidgetHost` puts every registered widget on the shared `GlassPanel`, so the glass (Frosted or Liquid, from the global switch) is never drawn by the widget: its QML file only draws content, reads its own `width` / `height` and blends between the small and the large layout (see `qml/widgets/F1Widget.qml`).
* **A track outline (Formula 1 widget):** add the circuit to `tools/f1/circuit-map.json` (Jolpica `circuitId` -> id in bacinger/f1-circuits) and run `tools/f1/build_circuits.py` as written in its header; `tools/f1/outline-sheet.sh calendar.json sheet.png` draws all outlines of a calendar to check them by eye (closed, no spikes).
* **A new widget and monitors:** nothing to do. The shell creates one window per widget AND monitor it is assigned to, and positions, sizes and the glass wallpaper come from the widget's monitor. Two rules: fetch data through a shared feed (`Feed` in `qml/core/Feed.qml`: a key that contains everything that changes the command, a command, an interval) and never start a `Process` per widget instance, and never assume a screen size - use the widget's own `width` / `height`.
* **Icons** are drawn by the project (`qml/core/Icons.js`, 24x24 line icons). Do not add icon fonts or copy icons from elsewhere without a compatible licence.
* **Licences:** only contribute code you wrote or that carries a free licence; say where it comes from in the pull request. Code without a licence cannot be accepted.
* **Scope:** Arch Linux + Hyprland + Quickshell only. Config changes always go to a separate file and only after asking; nothing may stop or disable other programs.
* `release.sh` is a maintainer tool (German messages) that tags and publishes a version.
