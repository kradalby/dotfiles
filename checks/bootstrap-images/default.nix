{
  pkgs,
  inputs,
  self,
}:
let
  live = self.packages.x86_64-linux.installer-iso.passthru.config;
in
assert !live.services.tailscale.enable;
assert !(live.systemd.services ? tailscaled-autoconnect);
pkgs.testers.runNixOSTest {
  name = "bootstrap-enrollment";

  nodes.control.imports = [ inputs.headscale.nixosModules.testkit ];
  nodes.host = { lib, ... }: {
    imports = [
      inputs.ragenix.nixosModules.age
      inputs.tailscale.nixosModules.default
      ../../common/bootstrap-common.nix
      ../../images/examples/wifi
    ];
    age.identityPaths = [ "/tmp/shared/identity" ];
    age.secrets.tailscale-preauthkey.file = lib.mkForce "/tmp/shared/join.age";
    age.secrets.wifi.file = lib.mkForce "/tmp/shared/wifi.age";
    services.tailscale.extraUpFlags = [ "--login-server=http://control" ];
    networking.useDHCP = lib.mkForce false;
    boot.kernelModules = [ "mac80211_hwsim" ];
    # The QEMU profile disables wireless by default.
    networking.wireless.enable = lib.mkOverride 0 true;
    networking.wireless.interfaces = [ "wlan1" ];
    services.hostapd = {
      enable = true;
      radios.wlan0 = {
        band = "2g";
        channel = 6;
        countryCode = "US";
        networks.wlan0 = {
          ssid = "test-wifi";
          authentication = {
            mode = "wpa2-sha1";
            wpaPasswordFile = pkgs.writeText "test-password" "test-password";
          };
        };
      };
    };
  };

  testScript = ''
    import json
    import subprocess

    control.start()
    key = control.succeed("hs-authkey test --reusable=false").strip()
    identity = host.shared_dir / "identity"
    subprocess.run(["${pkgs.age}/bin/age-keygen", "-o", identity], check=True)
    recipient = subprocess.check_output(["${pkgs.age}/bin/age-keygen", "-y", identity], text=True).strip()
    subprocess.run(["${pkgs.age}/bin/age", "-r", recipient, "-o", host.shared_dir / "join.age"],
                   input=key, text=True, check=True)
    subprocess.run(["${pkgs.age}/bin/age", "-r", recipient, "-o", host.shared_dir / "wifi.age"],
                   input='network={\nssid="test-wifi"\npsk="test-password"\n}\n', text=True, check=True)

    control.succeed("systemctl stop headscale")
    host.start()
    host.wait_for_unit("tailscaled.service")
    host.succeed("test -s /run/agenix/tailscale-preauthkey")
    host.wait_until_succeeds("${pkgs.iw}/bin/iw dev wlan1 link | grep -F 'SSID: test-wifi'")
    control.succeed("systemctl start headscale")
    host.wait_until_succeeds("tailscale status")
    first = json.loads(host.succeed("tailscale status --json"))["Self"]["ID"]
    assert first
    host.shutdown()
    host.start()
    host.wait_until_succeeds("tailscale status")
    assert json.loads(host.succeed("tailscale status --json"))["Self"]["ID"] == first
    assert len(json.loads(control.succeed("headscale nodes list -o json"))) == 1
  '';
}
