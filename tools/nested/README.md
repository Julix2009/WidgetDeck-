# Nested test session (for developers)

Runs WidgetDeck in a Hyprland window inside your own session (own D-Bus, own HOME) so layouts, widgets and monitors can be tried and screenshotted
without touching your desktop. Virtual monitors: `hyprctl output create headless HEAD-2`. Needs: hyprland, quickshell, grim, jq, imagemagick; awww for wallpapers.

    source tools/nested/env.sh            # sets NB (default /tmp/widgetdeck-nested), N (the session home), q / qlog / nh / nexec helpers
    tools/nested/start.sh                 # create the session home from qml/ (first time) and start the nested Hyprland (opens on workspace 9)
    tools/nested/sync.sh && tools/nested/restart.sh    # copy qml/ into it, restart the shell inside
    tools/nested/shot.sh out.png [grim args]           # screenshot of the nested session (workspace 9 is shown for a moment)
    tools/nested/stop.sh                  # stop it
