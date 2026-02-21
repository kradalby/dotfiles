{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.syncthings;
  settingsFormat = pkgs.formats.json {};

  # Determine if a GUI address is a Unix socket
  isUnixGui = addr: (builtins.substring 0 1 addr) == "/";

  # Generate curl address args for both network and Unix socket GUI addresses.
  curlAddressArgs = guiAddress: path:
    if isUnixGui guiAddress
    then "--unix-socket ${guiAddress} http://.${path}"
    else "${guiAddress}${path}";

  # Build a list of device configs from the settings attrset, adding deviceID
  # field expected by the REST API.
  mkDevices = icfg:
    lib.mapAttrsToList (
      _: device:
        device
        // {
          deviceID = device.id;
        }
    )
    icfg.settings.devices;

  # Build a list of folder configs, resolving device names to IDs and
  # filtering out disabled folders.
  mkFolders = icfg:
    lib.mapAttrsToList (
      _: folder:
        folder
        // lib.throwIf (folder ? rescanInterval || folder ? watch || folder ? watchDelay)
        ''
          The options services.syncthings.<name>.settings.folders.<name>.{rescanInterval,watch,watchDelay}
          were removed. Please use, respectively, {rescanIntervalS,fsWatcherEnabled,fsWatcherDelayS} instead.
        ''
        {
          devices = let
            folderDevices = folder.devices;
          in
            map (
              device:
                if builtins.isString device
                then {deviceId = icfg.settings.devices.${device}.id;}
                else if builtins.isAttrs device
                then {deviceId = icfg.settings.devices.${device.name}.id;} // device
                else throw "Invalid type for devices in folder; expected string or attrset."
            )
            folderDevices;
        }
    ) (lib.filterAttrs (_: folder: folder.enable) icfg.settings.folders);

  jq = "${pkgs.jq}/bin/jq";

  # Generate the updateConfig bash script for a specific instance.
  mkUpdateConfig = name: icfg: let
    cleanedConfig = lib.converge (lib.filterAttrsRecursive (_: v: v != null && v != {})) icfg.settings;
    devices = mkDevices icfg;
    folders = mkFolders icfg;
    curlAddr = curlAddressArgs icfg.guiAddress;
  in
    pkgs.writers.writeBash "merge-syncthing-config-${name}" (
      ''
        set -efu

        # be careful not to leak secrets in the filesystem or in process listings
        umask 0077

        curl() {
            # get the api key by parsing the config.xml
            while
                ! ${pkgs.libxml2}/bin/xmllint \
                    --xpath 'string(configuration/gui/apikey)' \
                    ${icfg.configDir}/config.xml \
                    >"$RUNTIME_DIRECTORY/api_key"
            do sleep 1; done
            (printf "X-API-Key: "; cat "$RUNTIME_DIRECTORY/api_key") >"$RUNTIME_DIRECTORY/headers"
            ${pkgs.curl}/bin/curl -sSLk -H "@$RUNTIME_DIRECTORY/headers" \
                --retry 1000 --retry-delay 1 --retry-all-errors \
                "$@"
        }
      ''
      +
      # Syncthing's REST API for folders and devices is almost identical.
      # We iterate both and generate shell commands for each at the same time.
      (
        lib.pipe
        {
          devs = {
            new_conf_IDs = map (v: v.id) devices;
            GET_IdAttrName = "deviceID";
            override = icfg.overrideDevices;
            conf = devices;
            baseAddress = curlAddr "/rest/config/devices";
          };
          dirs = {
            new_conf_IDs = map (v: v.id) folders;
            GET_IdAttrName = "id";
            override = icfg.overrideFolders;
            conf = folders;
            baseAddress = curlAddr "/rest/config/folders";
            ignoreAddress = curlAddr "/rest/db/ignores";
          };
        }
        [
          (lib.mapAttrs (
            conf_type: s:
              lib.pipe s.conf [
                (map (
                  new_cfg: let
                    jsonPreSecretsFile = pkgs.writeTextFile {
                      name = "${conf_type}-${new_cfg.id}-conf-pre-secrets.json";
                      text = builtins.toJSON (removeAttrs new_cfg ["ignorePatterns"]);
                    };
                    injectSecretsJqCmd =
                      {
                        "devs" = "${jq} .";
                        "dirs" = let
                          folder = new_cfg;
                          devicesWithSecrets = lib.pipe folder.devices [
                            (lib.filter (device: (builtins.isAttrs device) && device ? encryptionPasswordFile))
                            (map (device: {
                              deviceId = device.deviceId;
                              variableName = "secret_${builtins.hashString "sha256" device.encryptionPasswordFile}";
                              secretPath = device.encryptionPasswordFile;
                            }))
                          ];
                          jqUpdates =
                            map (device: ''
                              .devices[] |= (
                                if .deviceId == "${device.deviceId}" then
                                  del(.encryptionPasswordFile) |
                                  .encryptionPassword = ''$${device.variableName}
                                else
                                  .
                                end
                              )
                            '')
                            devicesWithSecrets;
                          jqRawFiles =
                            map (
                              device: "--rawfile ${device.variableName} ${lib.escapeShellArg device.secretPath}"
                            )
                            devicesWithSecrets;
                        in "${jq} ${lib.concatStringsSep " " jqRawFiles} ${
                          lib.escapeShellArg (lib.concatStringsSep "|" (["."] ++ jqUpdates))
                        }";
                      }
                      .${
                        conf_type
                      };
                  in
                    ''
                      ${injectSecretsJqCmd} ${jsonPreSecretsFile} | curl --json @- -X POST ${s.baseAddress}
                    ''
                    + lib.optionalString ((conf_type == "dirs") && (new_cfg.ignorePatterns != null)) ''
                      curl -d '{"ignore": ${builtins.toJSON new_cfg.ignorePatterns}}' -X POST ${s.ignoreAddress}?folder=${new_cfg.id}
                    ''
                ))
                (lib.concatStringsSep "\n")
              ]
              + lib.optionalString s.override ''
                stale_${conf_type}_ids="$(curl -X GET ${s.baseAddress} | ${jq} \
                  --argjson new_ids ${lib.escapeShellArg (builtins.toJSON s.new_conf_IDs)} \
                  --raw-output \
                  '[.[].${s.GET_IdAttrName}] - $new_ids | .[]'
                )"
                for id in ''${stale_${conf_type}_ids}; do
                  >&2 echo "Deleting stale device: $id"
                  curl -X DELETE ${s.baseAddress}/$id
                done
              ''
          ))
          builtins.attrValues
          (lib.concatStringsSep "\n")
        ]
      )
      +
      # Update remaining settings (gui, options, etc.)
      (lib.pipe cleanedConfig [
        builtins.attrNames
        (lib.subtractLists [
          "folders"
          "devices"
          "guiPasswordFile"
        ])
        (map (subOption: ''
          curl -X PUT -d ${
            lib.escapeShellArg (builtins.toJSON cleanedConfig.${subOption})
          } ${curlAddr "/rest/config/${subOption}"}
        ''))
        (lib.concatStringsSep "\n")
      ])
      +
      # Hash guiPasswordFile with bcrypt and PATCH the GUI config.
      (lib.optionalString (icfg.guiPasswordFile != null) ''
        ${pkgs.mkpasswd}/bin/mkpasswd -m bcrypt --stdin <"${icfg.guiPasswordFile}" | tr -d "\n" > "$RUNTIME_DIRECTORY/password_bcrypt"
        curl -X PATCH --variable "pw_bcrypt@$RUNTIME_DIRECTORY/password_bcrypt" --expand-json '{ "password": "{{pw_bcrypt}}" }' ${curlAddr "/rest/config/gui"}
      '')
      + ''
        # restart Syncthing if required
        if curl ${curlAddr "/rest/config/restart-required"} |
           ${jq} -e .requiresRestart > /dev/null; then
            curl -X POST ${curlAddr "/rest/system/restart"}
        fi
      ''
    );

  # Per-instance option declarations, factored out for readability.
  instanceOptions = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "this Syncthing instance";

      package = lib.mkPackageOption pkgs "syncthing" {};

      cert = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to the `cert.pem` file, which will be copied into Syncthing's
          configDir.
        '';
      };

      key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to the `key.pem` file, which will be copied into Syncthing's
          configDir.
        '';
      };

      guiPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to file containing the plaintext password for Syncthing's GUI.
        '';
      };

      overrideDevices = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to delete the devices which are not configured via the
          devices option. If set to `false`, devices added via the web
          interface will persist and will have to be deleted manually.
        '';
      };

      overrideFolders = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to delete the folders which are not configured via the
          folders option. If set to `false`, folders added via the web
          interface will persist and will have to be deleted manually.

          Note: if any device has `autoAcceptFolders` enabled, you must
          set this to `false` to avoid conflicts.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.submodule {
          freeformType = settingsFormat.type;
          options = {
            # Global syncthing options
            options = lib.mkOption {
              default = {};
              description = "Global configuration options.";
              type = lib.types.submodule (
                {...}: {
                  freeformType = settingsFormat.type;
                  options = {
                    localAnnounceEnabled = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Whether to send announcements to the local LAN.";
                    };

                    localAnnouncePort = lib.mkOption {
                      type = lib.types.nullOr lib.types.port;
                      default = null;
                      description = "Port for IPv4 broadcast announcements.";
                    };

                    relaysEnabled = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Whether to use relay connections.";
                    };

                    urAccepted = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                      description = "Whether the user has accepted to submit anonymous usage data.";
                    };

                    limitBandwidthInLan = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Whether to apply bandwidth limits to LAN devices.";
                    };

                    maxFolderConcurrency = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                      description = "Max folders concurrently in I/O-intensive operations.";
                    };
                  };
                }
              );
            };

            # Device settings
            devices = lib.mkOption {
              default = {};
              description = "Peers/devices which Syncthing should communicate with.";
              example = {
                bigbox = {
                  id = "7CFNTQM-IMTJBHJ-3UWRDIU-ZGQJFR6-VCXZ3NB-XUH3KZO-N52ITXR-LAIYUAU";
                  addresses = ["tcp://192.168.0.10:51820"];
                };
              };
              type = lib.types.attrsOf (lib.types.submodule (
                {name, ...}: {
                  freeformType = settingsFormat.type;
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The name of the device.";
                    };

                    id = lib.mkOption {
                      type = lib.types.str;
                      description = "The device ID.";
                    };

                    autoAcceptFolders = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Automatically create or share advertised folders.";
                    };
                  };
                }
              ));
            };

            # Folder settings
            folders = lib.mkOption {
              default = {};
              description = "Folders which should be shared by Syncthing.";
              type = lib.types.attrsOf (lib.types.submodule (
                {name, ...}: {
                  freeformType = settingsFormat.type;
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = ''
                        Whether to share this folder. Useful for defining all folders
                        centrally while disabling specific ones per machine.
                      '';
                    };

                    path = lib.mkOption {
                      type =
                        lib.types.str
                        // {
                          check = x: lib.types.str.check x && (builtins.substring 0 1 x == "/" || builtins.substring 0 2 x == "~/");
                          description = lib.types.str.description + " starting with / or ~/";
                        };
                      default = name;
                      description = "The path to the folder which should be shared.";
                    };

                    id = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The ID of the folder. Must be the same on all devices.";
                    };

                    label = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The label of the folder.";
                    };

                    type = lib.mkOption {
                      type = lib.types.enum [
                        "sendreceive"
                        "sendonly"
                        "receiveonly"
                        "receiveencrypted"
                      ];
                      default = "sendreceive";
                      description = "Controls how the folder is handled by Syncthing.";
                    };

                    devices = lib.mkOption {
                      type = lib.types.listOf (
                        lib.types.oneOf [
                          lib.types.str
                          (lib.types.submodule (
                            {...}: {
                              freeformType = settingsFormat.type;
                              options = {
                                name = lib.mkOption {
                                  type = lib.types.str;
                                  description = "The name of a device defined in the devices option.";
                                };

                                encryptionPasswordFile = lib.mkOption {
                                  type = lib.types.nullOr lib.types.str;
                                  default = null;
                                  description = "Path to encryption password file.";
                                };
                              };
                            }
                          ))
                        ]
                      );
                      default = [];
                      description = "The devices this folder should be shared with.";
                    };

                    versioning = lib.mkOption {
                      default = null;
                      description = "How to keep changed/deleted files.";
                      type = lib.types.nullOr (lib.types.submodule {
                        freeformType = settingsFormat.type;
                        options = {
                          type = lib.mkOption {
                            type = lib.types.enum [
                              "external"
                              "simple"
                              "staggered"
                              "trashcan"
                            ];
                            description = "The type of versioning.";
                          };
                        };
                      });
                    };

                    copyOwnershipFromParent = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Try to copy file/folder ownership from the parent directory.";
                    };

                    ignorePatterns = lib.mkOption {
                      type = lib.types.nullOr (lib.types.listOf lib.types.str);
                      default = null;
                      description = "Syncthing ignore patterns for this folder.";
                    };
                  };
                }
              ));
            };
          };
        };
        default = {};
        description = ''
          Extra configuration options for Syncthing (JSON REST API format).
          See <https://docs.syncthing.net/users/config.html>.
        '';
      };

      guiAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:8384";
        description = ''
          The address to serve the web interface at.
          Must be unique across all instances on the same machine.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        description = "The user to run Syncthing as.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "syncthing";
        description = ''
          The group to run Syncthing under.
          If set to "syncthing", the group is created automatically.
        '';
      };

      all_proxy = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "socks5://address.com:1234";
        description = ''
          Overwrites the all_proxy environment variable for the Syncthing
          process. Used for SOCKS5 proxy connections.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/syncthing/${name}";
        defaultText = lib.literalExpression ''"/var/lib/syncthing/''${name}"'';
        description = ''
          The path where synchronised directories will exist.
          Each instance gets its own directory under /var/lib/syncthing/.
        '';
      };

      configDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/syncthing/${name}/config";
        defaultText = lib.literalExpression ''"/var/lib/syncthing/''${name}/config"'';
        description = "The path where the settings and keys will exist.";
      };

      databaseDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/syncthing/${name}/db";
        defaultText = lib.literalExpression ''"/var/lib/syncthing/''${name}/db"'';
        description = "The directory containing the database and logs.";
      };

      extraFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["--reset-deltas"];
        description = "Extra flags passed to the syncthing command.";
      };

      openDefaultPorts = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to open the default ports in the firewall: TCP/UDP 22000
          for transfers and UDP 21027 for discovery.

          If multiple instances are running on this machine, you will need
          to manually open a set of ports for each instance and leave this
          disabled.
        '';
      };
    };
  };
in {
  ###### interface
  options.services.syncthings = lib.mkOption {
    description = ''
      Multiple Syncthing instances. Each attribute defines an independent
      Syncthing instance with its own configuration, user, and data directory.
    '';
    default = {};
    type = lib.types.attrsOf (lib.types.submodule instanceOptions);
  };

  ###### implementation
  config = lib.mkIf (cfg != {}) {
    assertions = lib.flatten (lib.mapAttrsToList (
        name: icfg:
          lib.optionals icfg.enable [
            {
              assertion = !(icfg.overrideFolders && builtins.any (dev: dev.autoAcceptFolders) (mkDevices icfg));
              message = ''
                services.syncthings.${name}.overrideFolders is true but some devices
                have autoAcceptFolders enabled. This will delete auto-accepted folders
                from the configuration, creating path conflicts. Set overrideFolders
                to false.
              '';
            }
            {
              assertion = (lib.hasAttrByPath ["gui" "password"] icfg.settings) -> icfg.guiPasswordFile == null;
              message = ''
                services.syncthings.${name}: Please use only one of
                settings.gui.password or guiPasswordFile.
              '';
            }
          ]
      )
      cfg);

    environment.systemPackages = lib.concatMap (
      icfg:
        lib.optional icfg.enable icfg.package
    ) (lib.attrValues cfg);

    networking.firewall = lib.mkMerge (lib.mapAttrsToList (
        name: icfg:
          lib.mkIf (icfg.enable && icfg.openDefaultPorts) {
            allowedTCPPorts = [22000];
            allowedUDPPorts = [21027 22000];
          }
      )
      cfg);

    systemd.services = lib.mkMerge (lib.mapAttrsToList (
        name: icfg: let
          isUnixGuiAddr = isUnixGui icfg.guiAddress;
          cleanedConfig = lib.converge (lib.filterAttrsRecursive (_: v: v != null && v != {})) icfg.settings;
          updateConfig = mkUpdateConfig name icfg;
        in
          lib.mkIf icfg.enable {
            "syncthing-${name}" = {
              description = "Syncthing service (${name})";
              after = ["network.target"];
              wantedBy = ["multi-user.target"];
              environment =
                {
                  STNORESTART = "yes";
                  STNOUPGRADE = "yes";
                  inherit (icfg) all_proxy;
                }
                // config.networking.proxy.envVars;
              serviceConfig = {
                Restart = "on-failure";
                SuccessExitStatus = "3 4";
                RestartForceExitStatus = "3 4";
                User = icfg.user;
                Group = icfg.group;
                StateDirectory = "syncthing/${name}";
                ExecStartPre =
                  lib.mkIf (icfg.cert != null || icfg.key != null)
                  "+${pkgs.writers.writeBash "syncthing-${name}-copy-keys" ''
                    install -dm700 -o ${icfg.user} -g ${icfg.group} ${icfg.configDir}
                    ${lib.optionalString (icfg.cert != null) ''
                      install -Dm644 -o ${icfg.user} -g ${icfg.group} ${toString icfg.cert} ${icfg.configDir}/cert.pem
                    ''}
                    ${lib.optionalString (icfg.key != null) ''
                      install -Dm600 -o ${icfg.user} -g ${icfg.group} ${toString icfg.key} ${icfg.configDir}/key.pem
                    ''}
                  ''}";
                ExecStart = let
                  args = lib.escapeShellArgs (
                    (lib.cli.toCommandLineGNU {} {
                      "no-browser" = true;
                      "gui-address" =
                        (
                          if isUnixGuiAddr
                          then "unix://"
                          else ""
                        )
                        + icfg.guiAddress;
                      "config" = icfg.configDir;
                      "data" = icfg.databaseDir;
                    })
                    ++ icfg.extraFlags
                  );
                in "${lib.getExe icfg.package} ${args}";
                MemoryDenyWriteExecute = true;
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateMounts = true;
                PrivateTmp = true;
                PrivateUsers = true;
                ProtectControlGroups = true;
                ProtectHostname = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                CapabilityBoundingSet = [
                  "~CAP_SYS_PTRACE"
                  "~CAP_SYS_ADMIN"
                  "~CAP_SETGID"
                  "~CAP_SETUID"
                  "~CAP_SETPCAP"
                  "~CAP_SYS_TIME"
                  "~CAP_KILL"
                ];
              };
            };

            "syncthing-${name}-init" = lib.mkIf (cleanedConfig != {}) {
              description = "Syncthing configuration updater (${name})";
              requisite = ["syncthing-${name}.service"];
              after = ["syncthing-${name}.service"];
              wantedBy = ["multi-user.target"];

              serviceConfig = {
                User = icfg.user;
                RemainAfterExit = true;
                RuntimeDirectory = "syncthing-${name}-init";
                Type = "oneshot";
                ExecStart = updateConfig;
              };
            };
          }
      )
      cfg);
  };
}
