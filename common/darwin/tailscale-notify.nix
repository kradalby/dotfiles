# AppleScript applet that powers tailscale-switch-toggle notifications.
#
# macOS picks a notification's icon from the calling app's bundle, so we
# ship a minimal applet whose icon is Tailscale's and call it via `open`.
# terminal-notifier and alerter both hang on Sonoma+ waiting for an
# UNUserNotificationCenter authorization that never resolves headless.
#
# `open --args` and NSProcessInfo are both unreliable on macOS 26 for
# .app launches — Cocoa swallows argv before AppleScript sees it, and
# NSProcessInfo only sees the applet's own argv. We route the payload
# through a custom URL scheme instead: `open tailscalenotify://show?...`
# fires the `on open location` handler with the full URL. Percent
# decoding is delegated to /usr/bin/python3.
#
# Unlike rustic's FDA wrapper we cannot build the .app as a pure
# derivation: the AppleScript runtime binary (`applet`) lives in macOS
# and is only emitted by /usr/bin/osacompile, which is unavailable in
# the Nix sandbox. Instead, the .app is built at activation time. A
# sha256 stamp of the script + bundle id + URL scheme is recorded next
# to the bundle so rebuilds happen only when those inputs change; the
# icon, codesign, and Launch Services registration run every activation
# so a Tailscale.app upgrade refreshes the icon and any plist/icon
# mutation gets a fresh ad-hoc signature (macOS refuses to register
# notifications for bundles with stale signatures).
{
  lib,
  pkgs,
  ...
}: let
  appPath = "/Applications/TailscaleNotify.app";
  iconSource = "/Applications/Tailscale.app/Contents/Resources/AppIcon.icns";
  bundleId = "no.kradalby.TailscaleNotify";
  urlScheme = "tailscalenotify";
  appleScript = ''
    use scripting additions

    on parseURL(theURL)
      set py to "import sys,urllib.parse as u; p=u.urlparse(sys.argv[1]); q=u.parse_qs(p.query); print(q.get('title',['''])[0]); sys.stdout.write(q.get('msg',['''])[0])"
      set out to do shell script "/usr/bin/python3 -c " & quoted form of py & " " & quoted form of theURL
      set parts to paragraphs of out
      return {item 1 of parts, item 2 of parts}
    end parseURL

    on open location theURL
      set {ttl, msg} to my parseURL(theURL)
      display notification msg with title ttl
    end open location

    on run
      return
    end run
  '';
  urlTypesJson = builtins.toJSON [
    {
      CFBundleURLName = "Tailscale Notify URL";
      CFBundleURLSchemes = [urlScheme];
    }
  ];
  # Bump the version prefix to force a rebuild on existing hosts.
  inputStamp = builtins.hashString "sha256" "v2|${bundleId}|${urlScheme}|${appleScript}";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";

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
      PL="$APP/Contents/Info.plist"
      /usr/bin/plutil -replace CFBundleIdentifier \
        -string ${lib.escapeShellArg bundleId} "$PL"
      /usr/bin/plutil -insert CFBundleURLTypes \
        -json ${lib.escapeShellArg urlTypesJson} "$PL"
      /bin/echo "$WANT" > "$STAMP"
    else
      echo "TailscaleNotify.app up to date, skipping rebuild"
    fi

    # Always refresh icon; Tailscale.app upgrades replace the source .icns.
    if [ -f "$ICON" ]; then
      /bin/cp -f "$ICON" "$APP/Contents/Resources/applet.icns"
    fi
    # Re-sign every activation: icon copy and plist edits both invalidate
    # the ad-hoc signature osacompile emits, and macOS silently drops
    # notifications from bundles whose signature does not match.
    /usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1
    # Re-register so Launch Services picks up CDHash / URL scheme changes.
    ${lsregister} -f "$APP" >/dev/null 2>&1
    /usr/bin/touch "$APP"
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
