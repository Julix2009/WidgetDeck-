# Contributing

Thanks for helping! Bug reports and small fixes are the most useful things right now.

* **Bugs:** open an issue with the template and paste the output of `widgetdeck-doctor` (it hides your home directory and prints no location or wallpaper path).
* **Pull requests:** keep them small and focused. Run the checks before you push:
  ```bash
  shellcheck -x -S warning install.sh update.sh uninstall.sh lib/*.sh bin/* qml/core/*.sh qml/widgets/sysmon/*.sh qml/modules/*.sh tools/*.sh
  python3 tools/check-i18n.py        # every UI text needs an English source and a German entry
  node tools/snapengine-test.js      # grid / snapping tests
  node tools/timetable-test.js       # timetable logic
  node tools/weathercard-test.js     # weather card logic (needs network for one check, skipped without)
  tools/untis-test.sh                # Untis client against a local mock server (invented data)
  tools/secret-scan.sh               # no personal paths, tokens or coordinates
  ```
  The same checks run on GitHub for every pull request (they only check, nothing is deployed).
* **Texts:** English is the source language. In QML use `I18n.tr("English text")`, in shell scripts `t 'English text %s' arg`. German goes into `qml/core/i18n.js` and `lib/i18n.sh`. More languages: add a table next to `de`.
* **Another style for a widget** (see the music widget): add a choice option `skin` to the widget in `qml/widgets/Registry.js` (options that only apply to one style get `when: { key: "skin", is: "<value>" }`, per-style sizes go into `skinSizes`), put the new look into its own file next to the widget (`qml/widgets/<name>/<Skin>View.qml`, state and logic stay in the widget and are passed in as `host`), and let the widget crossfade between the views with a `Loader` that is only active while its style is selected. Add the new texts to `qml/core/i18n.js` and run the checks above.
* **A new weather icon** (see the weather card): add the part to `tools/weather-icons/parts.json` (rounded capsules / spheres, colours, smoothness) and run `tools/weather-icons/render.sh` to bake the sprite into `qml/widgets/weathercard/icons/`; then add a recipe for the weather kind in `layersFor()` in `qml/widgets/weathercard/Model.js` (which sprites, where, how they move) and, for a new kind, its code in `kindOf()`. `node tools/weathercard-test.js` checks that every weather code, day and night, maps to existing sprites.
* **Icons** are drawn by the project (`qml/core/Icons.js`, 24x24 line icons). Do not add icon fonts or copy icons from elsewhere without a compatible licence.
* **Licences:** only contribute code you wrote or that carries a free licence; say where it comes from in the pull request. Code without a licence cannot be accepted.
* **Scope:** Arch Linux + Hyprland + Quickshell only. Config changes always go to a separate file and only after asking; nothing may stop or disable other programs.
* `release.sh` is a maintainer tool (German messages) that tags and publishes a version.
