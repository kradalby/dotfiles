# AppleScript applet that powers tailscale-switch-toggle notifications.
#
# macOS picks the notification icon from the calling app's bundle, so we
# ship a minimal applet whose icon is Tailscale's and call it via `open`.
# terminal-notifier and alerter both hang on Sonoma+ waiting for an
# UNUserNotificationCenter authorization that never resolves headless.
{lib, ...}: let
  script = ''
    on run argv
      display notification (item 2 of argv) with title (item 1 of argv)
    end run
  '';
  bundleId = "no.kradalby.TailscaleNotify";
  # Bump the stamp version to force a rebuild on existing hosts.
  stamp = builtins.hashString "sha256" "v1|${bundleId}|${script}";
in {
  system.activationScripts.tailscaleNotifyApplet.text = ''
    APP="/Applications/TailscaleNotify.app"
    ICON="/Applications/Tailscale.app/Contents/Resources/AppIcon.icns"
    STAMP="$APP/Contents/.nix-stamp"
    WANT="${stamp}"

    if [ ! -d "$APP" ] || [ "$(/bin/cat "$STAMP" 2>/dev/null)" != "$WANT" ]; then
      /bin/rm -rf "$APP"
      /usr/bin/osacompile -o "$APP" -e ${lib.escapeShellArg script}
      /usr/bin/plutil -replace CFBundleIdentifier -string ${lib.escapeShellArg bundleId} \
        "$APP/Contents/Info.plist"
      /bin/echo "$WANT" > "$STAMP"
    fi
    # Always refresh icon; Tailscale.app upgrades replace the source .icns.
    if [ -f "$ICON" ]; then
      /bin/cp -f "$ICON" "$APP/Contents/Resources/applet.icns"
      /usr/bin/touch "$APP"
    fi
  '';
}
