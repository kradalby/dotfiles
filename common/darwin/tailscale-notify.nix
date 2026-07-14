# AppleScript applet that powers tailscale-switch-toggle notifications.
#
# The applet itself is built by the reusable ./notify-applet.nix builder
# (see there for why we use a URL-scheme applet rather than terminal-notifier
# or `display notification` from osascript). This module just instantiates it
# with Tailscale's bundle id, scheme, and icon, and wires the install script
# into nix-darwin activation.
{
  lib,
  pkgs,
  ...
}:
let
  notifier = import ./notify-applet.nix { inherit lib pkgs; } {
    appName = "TailscaleNotify";
    bundleId = "no.kradalby.TailscaleNotify";
    urlScheme = "tailscalenotify";
    iconSource = "/Applications/Tailscale.app/Contents/Resources/AppIcon.icns";
  };
in
{
  # nix-darwin only wires predefined activation phases (preActivation,
  # extraActivation, postActivation, postUserActivation); custom names
  # are silently ignored. mkAfter concats with other modules (rustic)
  # that also set postActivation.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${notifier.install}
  '';
}
