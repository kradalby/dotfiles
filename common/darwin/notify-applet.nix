# Reusable AppleScript notifier applet builder.
#
# macOS picks a notification's icon from the calling app's bundle, so we
# ship a minimal applet whose icon we control and call it via a custom URL
# scheme: `open <scheme>://show?title=..&msg=..&sound=..`. terminal-notifier
# and alerter both hang on Sonoma+ waiting for a UNUserNotificationCenter
# authorization that never resolves headless; `open --args` and NSProcessInfo
# are both unreliable for .app launches on macOS 26 (Cocoa swallows argv), so
# the payload is routed through the URL scheme instead. Percent decoding is
# delegated to /usr/bin/python3.
#
# `display notification` supports title/message/sound only — grouping
# (-group) and DND override (-ignoreDnD) are NOT available this way.
#
# Returns { install; } where `install` is a writeShellScript derivation the
# caller wires into system.activationScripts.postActivation. The applet is
# built at activation time: osacompile's `applet` runtime binary lives in
# macOS and is unavailable in the Nix sandbox, so this cannot be a pure
# derivation. A sha256 stamp of the script + bundle id + scheme is recorded
# next to the bundle; rebuilds happen only when those inputs change. The
# icon, codesign, and Launch Services registration run every activation so an
# icon-source upgrade refreshes the icon and any mutation gets a fresh ad-hoc
# signature (macOS refuses to register notifications for stale-signed bundles).
{
  lib,
  pkgs,
}: {
  appName, # e.g. "TailscaleNotify" -> /Applications/TailscaleNotify.app
  bundleId, # e.g. "no.kradalby.TailscaleNotify"
  urlScheme, # e.g. "tailscalenotify"
  iconSource ? null, # optional .icns path, copied in on every activation
}: let
  appPath = "/Applications/${appName}.app";
  appleScript = ''
    use scripting additions

    on parseURL(theURL)
      set py to "import sys,urllib.parse as u; p=u.urlparse(sys.argv[1]); q=u.parse_qs(p.query); print(q.get('title',['''])[0]); print(q.get('sound',['''])[0]); sys.stdout.write(q.get('msg',['''])[0])"
      set out to do shell script "/usr/bin/python3 -c " & quoted form of py & " " & quoted form of theURL
      set parts to paragraphs of out
      return {item 1 of parts, item 2 of parts, item 3 of parts}
    end parseURL

    on open location theURL
      set {ttl, snd, msg} to my parseURL(theURL)
      if snd is "" then
        display notification msg with title ttl
      else
        display notification msg with title ttl sound name snd
      end if
    end open location

    on run
      return
    end run
  '';
  urlTypesJson = builtins.toJSON [
    {
      CFBundleURLName = "${appName} URL";
      CFBundleURLSchemes = [urlScheme];
    }
  ];
  # Bump the version prefix to force a rebuild on existing hosts.
  inputStamp = builtins.hashString "sha256" "v3|${bundleId}|${urlScheme}|${appleScript}";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";
in {
  install = pkgs.writeShellScript "${urlScheme}-install" ''
    set -eu
    APP=${lib.escapeShellArg appPath}
    STAMP="$APP/Contents/.nix-stamp"
    WANT=${lib.escapeShellArg inputStamp}

    if [ ! -d "$APP" ] || [ "$(/bin/cat "$STAMP" 2>/dev/null)" != "$WANT" ]; then
      echo "installing ${appName}.app applet..."
      /bin/rm -rf "$APP"
      /usr/bin/osacompile -o "$APP" -e ${lib.escapeShellArg appleScript}
      PL="$APP/Contents/Info.plist"
      /usr/bin/plutil -replace CFBundleIdentifier \
        -string ${lib.escapeShellArg bundleId} "$PL"
      /usr/bin/plutil -insert CFBundleURLTypes \
        -json ${lib.escapeShellArg urlTypesJson} "$PL"
      /bin/echo "$WANT" > "$STAMP"
    else
      echo "${appName}.app up to date, skipping rebuild"
    fi

    ${lib.optionalString (iconSource != null) ''
      # Always refresh icon; the source .icns may change under us.
      if [ -f ${lib.escapeShellArg iconSource} ]; then
        /bin/cp -f ${lib.escapeShellArg iconSource} "$APP/Contents/Resources/applet.icns"
      fi
    ''}
    # Re-sign every activation: icon copy and plist edits both invalidate
    # the ad-hoc signature osacompile emits, and macOS silently drops
    # notifications from bundles whose signature does not match.
    /usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1
    # Re-register so Launch Services picks up CDHash / URL scheme changes.
    ${lsregister} -f "$APP" >/dev/null 2>&1
    /usr/bin/touch "$APP"
  '';
}
