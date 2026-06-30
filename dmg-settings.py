# dmgbuild settings for the styled loqui installer DMG.
# Invoked by release.sh:  dmgbuild -s dmg-settings.py -D app=<app> "loqui" <out.dmg>
# dmgbuild writes the window layout directly into the volume's .DS_Store (no Finder
# automation), which is why it works reliably on new macOS where create-dmg's
# AppleScript styling silently fails.

import os.path

app = defines.get("app", "build/loqui.app")
appname = os.path.basename(app)

# --- contents ---
files = [app]
symlinks = {"Applications": "/Applications"}

# --- window ---
# Background is exactly 720x405 (1x), so the window matches it pixel-for-point and
# the art fills the window with no gaps.
background = "design/dmg/loqui-dmg-bg.png"
window_rect = ((200, 120), (720, 405))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
label_pos = "bottom"
text_size = 13
icon_size = 110

# Icon centers, in points from the window's top-left — placed on the arrow line,
# loqui on the left, Applications on the right.
icon_locations = {
    appname: (185, 200),
    "Applications": (535, 200),
}

format = "UDZO"
