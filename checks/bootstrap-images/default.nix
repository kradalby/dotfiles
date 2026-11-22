{ pkgs, inputs }:
let
  images = import ../../images {
    inputs = inputs // {
      image-config = ./profile;
    };
  };
  iso = images.x86_64-linux.installer-iso;
  keys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  # Two boots of the same disk. Only the first VM has the installer CD attached.
  disk.virtualisation = {
    diskImage = "../bootstrap.qcow2";
    diskSize = 8192;
    memorySize = 2048;
    useBootLoader = true;
    useEFIBoot = true;
    useDefaultFilesystems = false;
    efi.keepVariables = false;
    fileSystems."/" = {
      device = "/dev/vda2";
      fsType = "ext4";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "bootstrap-enrollment";
  globalTimeout = 900;
  nodes.control = {
    imports = [ inputs.headscale.nixosModules.testkit ];
    services.headscale.settings.policy = {
      mode = "file";
      path = pkgs.writeText "policy.hujson" ''
        {
          "acls": [{"action":"accept","src":["*"],"dst":["*:*"]}],
          "ssh": [{"action":"accept","src":["autogroup:member"],"dst":["autogroup:self"],"users":["root"]}]
        }
      '';
    };
    services.tailscale.enable = true;
    services.tailscale.openFirewall = true;
  };
  nodes.installer = {
    imports = [ disk ];
    virtualisation.qemu.options = [ "-cdrom ${iso}/iso/handoff-installer.iso" ];
  };
  nodes.target = disk;
  testScript = ''
    import json
    import shlex

    control.start()
    control.succeed("install -m 600 ${keys.snakeOilPrivateKey} /root/test-key")
    ssh = "ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -i /root/test-key root@192.168.1.10 "
    def remote(command: str) -> str:
        return control.succeed(ssh + shlex.quote(command))

    control.wait_for_unit("headscale.service")
    control.wait_for_unit("tailscaled.service")
    control.succeed('tailscale up --login-server=http://192.168.1.1 --auth-key="$(hs-authkey test --reusable=false)"')
    installer.start()
    control.wait_until_succeeds(ssh + "mountpoint -q /iso", timeout=180)
    control.succeed("hs-authkey test --reusable=false | " + ssh + "'umask 077; cat > /run/test-join-key && systemctl restart --no-block tailscaled-autoconnect'")
    control.wait_until_succeeds(ssh + "tailscale status")
    first = json.loads(remote("tailscale status --json"))["Self"]
    assert first["ID"] and first["TailscaleIPs"]
    ssh = "ssh -o BatchMode=yes -o PubkeyAuthentication=no -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new root@" + first["TailscaleIPs"][0] + " "
    control.wait_until_succeeds(ssh + "true", timeout=120)
    fingerprint = remote("ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub")
    remote("parted -s /dev/vda mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 esp on mkpart root ext4 513MiB 100% && udevadm settle")
    remote("mkfs.fat -F 32 -n ESP /dev/vda1 && mkfs.ext4 -q -L nixos /dev/vda2 && mount -t ext4 /dev/vda2 /mnt && mount -t vfat --mkdir /dev/vda1 /mnt/boot")
    remote("systemctl start --no-block install-bootstrap")
    installer.wait_for_shutdown()

    target.start()
    control.wait_until_succeeds(ssh + "tailscale status", timeout=180)
    assert remote("ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub") == fingerprint
    remote("test ! -e /run/test-join-key && ! mountpoint -q /iso")
    after = json.loads(remote("tailscale status --json"))["Self"]
    assert (after["ID"], after["TailscaleIPs"]) == (first["ID"], first["TailscaleIPs"])
    assert len(json.loads(control.succeed("headscale nodes list -o json"))) == 2
  '';
}
