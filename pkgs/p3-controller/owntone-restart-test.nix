{
  name = "p3-controller-owntone-restart";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../../modules/owntone.nix ];
      services.avahi.enable = true;

      services.owntone = {
        enable = true;
        package = pkgs.writeShellScriptBin "owntone" ''
          exec ${pkgs.coreutils}/bin/sleep infinity
        '';
        controller = {
          enable = true;
          package = pkgs.writeShellScriptBin "p3-controller" ''
            exec ${pkgs.coreutils}/bin/sleep infinity
          '';
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("owntone.service")
    machine.wait_for_unit("p3-controller.service")
    owntone_pid = machine.succeed("systemctl show -p MainPID --value owntone.service").strip()
    controller_pid = machine.succeed("systemctl show -p MainPID --value p3-controller.service").strip()
    machine.succeed("systemctl kill --kill-whom=main --signal=SIGKILL owntone.service")
    machine.wait_until_succeeds(
        f'test "$(systemctl show -p MainPID --value owntone.service)" != "{owntone_pid}" '
        '&& systemctl is-active owntone.service'
    )
    machine.wait_for_unit("p3-controller.service")
    assert machine.succeed("systemctl show -p MainPID --value p3-controller.service").strip() == controller_pid
  '';
}
