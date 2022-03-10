{ config, lib, pkgs, ... }: {

  containers.active-directory =
    {
      config =
        { config, pkgs, ... }:
          with lib;

          let
            cfg = config.services.samba;
            samba = cfg.package;
            nssModulesPath = config.system.nssModules.path;
            adDomain = "ad.fap.no";
            adWorkgroup = "fap";
            adNetbiosName = "FAP";
            staticIp = "";
          in
          {
            # Disable resolveconf, we're using Samba internal DNS backend
            systemd.services.resolvconf.enable = false;
            environment.etc = {
              resolvconf = {
                text = ''
                  search ${adDomain}
                  nameserver ${staticIp}
                '';
              };
            };

            # Rebuild Samba with LDAP, MDNS and Domain Controller support
            nixpkgs.overlays = [
              (self: super: {
                samba = super.samba.override {
                  enableLDAP = true;
                  enableMDNS = true;
                  enableDomainController = true;
                };
              })
            ];

            # Disable default Samba `smbd` service, we will be using the `samba` server binary
            systemd.services.samba-smbd.enable = false;
            systemd.services.samba = {
              description = "Samba Service Daemon";

              requiredBy = [ "samba.target" ];
              partOf = [ "samba.target" ];

              serviceConfig = {
                ExecStart = "${samba}/sbin/samba --foreground --no-process-group";
                ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                LimitNOFILE = 16384;
                PIDFile = "/run/samba.pid";
                Type = "notify";
                NotifyAccess = "all"; #may not do anything...
              };
              unitConfig.RequiresMountsFor = "/var/lib/samba";
            };
            services.samba = {
              enable = true;
              enableNmbd = false;
              enableWinbindd = false;
              configText = ''
                # Global parameters
                [global]
                    dns forwarder = ${staticIp}
                    netbios name = ${adNetbiosName}
                    realm = ${toUpper adDomain}
                    server role = active directory domain controller
                    workgroup = ${adWorkgroup}
                    idmap_ldb:use rfc2307 = yes

                [sysvol]
                    path = /var/lib/samba/sysvol
                    read only = No

                [netlogon]
                    path = /var/lib/samba/sysvol/${adDomain}/scripts
                    read only = No
              '';
            };
          };
    };
}
