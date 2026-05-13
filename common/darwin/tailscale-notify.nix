# AppleScript applet that powers tailscale-switch-toggle notifications.
#
# macOS picks a notification's icon from the calling app's bundle, so we
# ship a minimal applet whose icon is Tailscale's and call it via `open`.
# terminal-notifier and alerter both hang on Sonoma+ waiting for an
# UNUserNotificationCenter authorization that never resolves headless.
#
# Unlike rustic's FDA wrapper we cannot build the .app as a pure
# derivation: the AppleScript runtime binary (`applet`) lives in macOS
# and is only emitted by /usr/bin/osacompile, which is unavailable in
# the Nix sandbox. Instead, the .app is built at activation time. A
# sha256 stamp of the script + bundle id is recorded next to the bundle
# so rebuilds happen only when those inputs change; the icon is copied
# every activation so a Tailscale.app upgrade refreshes it.
{
  lib,
  pkgs,
  ...
}: let
  appPath = "/Applications/TailscaleNotify.app";
  iconSource = "/Applications/Tailscale.app/Contents/Resources/AppIcon.icns";
  bundleId = "no.kradalby.TailscaleNotify";
  appleScript = ''
    on run argv
      display notification (item 2 of argv) with title (item 1 of argv)
    end run
  '';
  # Bump the version prefix to force a rebuild on existing hosts.
  inputStamp = builtins.hashString "sha256" "v1|${bundleId}|${appleScript}";

  installApplet = pkgs.writeShellScript "tailscale-notify-install" ''
    set -eu
    APP=${lib.escapeShellArg appPath}
    ICON=${lib.escapeShellArg iconSource}
    STAMP="$APP/Contents/.nix-stamp"
    WANT=${lib.escapeShellArg inputStamp}

    if [ ! -d "$APP" ] || [ "$(/bin/cat "$STAMP" 2>/dev/null)" != "$WANT" ]; then
      echo "installing TailscaleNotify.app applet..."
      /bin/rm -rf "$APP"
      /usr/bin/osacompile -o "$APP" -e ${lib.escapeShellArg appleScript}
      /usr/bin/plutil -replace CFBundleIdentifier \
        -string ${lib.escapeShellArg bundleId} \
        "$APP/Contents/Info.plist"
      /bin/echo "$WANT" > "$STAMP"
    else
      echo "TailscaleNotify.app up to date, skipping rebuild"
    fi

    # Always refresh icon; Tailscale.app upgrades replace the source .icns.
    if [ -f "$ICON" ]; then
      /bin/cp -f "$ICON" "$APP/Contents/Resources/applet.icns"
      /usr/bin/touch "$APP"
    fi
  '';
in {
  # nix-darwin only wires predefined activation phases (preActivation,
  # extraActivation, postActivation, postUserActivation); custom names
  # are silently ignored. mkAfter concats with other modules (rustic)
  # that also set postActivation.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${installApplet}
  '';
}
