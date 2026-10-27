#!/bin/sh
# mise postinstall for a tool downloaded as a macOS DMG. mise saves the DMG without unpacking it,
# so copy the .app bundle out of the image and remove the image.
#
# Lineage:
#   run by   mise, as the postinstall of each desktop app tool in mise.toml
#   writes   <app>.app in the tool's install folder; registers it with LaunchServices
#   undone   mise-tasks/apps/uninstall
set -e
# mise sets this for a postinstall. Run any other way, stop before touching anything.
: "${MISE_TOOL_INSTALL_PATH:?is not set: this script is the mise postinstall hook, not something to run by hand}"
cd "$MISE_TOOL_INSTALL_PATH"
dmg=$(ls) # the download is the only file in the install directory
mnt=$(mktemp -d)
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$dmg"
app=$(basename "$mnt"/*.app)
ditto "$mnt/$app" "$app"
hdiutil detach -quiet "$mnt"
rmdir "$mnt"
rm "$dmg"
# Register the app with LaunchServices: scripts/app-open.sh opens it by name (`open -a`),
# which can't find an app outside /Applications that macOS has never seen.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
