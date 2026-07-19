{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Default build set for repos with no garnix.yaml (our fork reads
  # GARNIX_DEFAULT_CONFIG). Drops darwinConfigurations — no macOS builders.
  garnixDefaultConfig = (pkgs.formats.yaml { }).generate "garnix-default-config.yaml" {
    builds.include = [
      "*.x86_64-linux.*"
      "defaultPackage.x86_64-linux"
      "devShell.x86_64-linux"
      "homeConfigurations.*"
      "nixosConfigurations.*"
    ];
  };
in
{
  # garnix CI coordinator + action-runner in an Incus VM; gigabuilder is its
  # remote builder, so the untrusted GitHub-facing parts stay in this guest while
  # realisation runs on bare metal. Operational docs live in ./README.md.
  imports = [
    ../../common/base.nix
    ../../common/tailscale.nix
    ../../common/incus.nix
    # systemd_exporter (:9558) with restart-count; node_exporter (:9100) already
    # comes via base.nix. Both are exposed over the tailnet by the tailscale0
    # firewall rules below — see the monitoring block near the datastores.
    ../../common/systemd-exporter.nix
    # Postgres + OpenSearch are separate fork modules; co-located below instead.
    inputs.garnix-ci.nixosModules.garnix
  ];

  # A consumed flake exposes `.inputs` but not `self`; graft it back on for the
  # garnix module's specialArgs.
  _module.args = {
    flakeInputs = inputs.garnix-ci.inputs // {
      self = inputs.garnix-ci;
    };
    flakePackages = inputs.garnix-ci.packages.x86_64-linux;
  };

  networking = {
    hostName = "garnix";
    domain = "fap.no";
    # Static address so the host's nginx proxy and builder-SSH target are stable.
    nameservers = [ "10.68.0.1" ];
    interfaces.${config.my.lan}.ipv4.addresses = [
      {
        address = "10.68.10.10";
        prefixLength = 16;
      }
    ];
    defaultGateway = {
      address = "10.68.0.1";
      interface = config.my.lan;
    };
  };

  # sfiber tailnet membership (tag:ci, forced by the preauth key): the
  # notify-deployd action pokes the sfiber deploy hosts after green CI.
  # pasta mirrors the VM's own address into the action sandbox, so actions
  # reach this proxy only via host.containers.internal -> host loopback;
  # bind everything (VM firewall keeps it off the wire), the sfiber ACL
  # caps what tag:ci reaches to deployd's poke port.
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-ci-preauthkey.path;
    extraUpFlags = [ "--login-server=https://headscale.sandefjordfiber.no" ];
    extraSetFlags = [ "--hostname=garnix" ];
    extraDaemonFlags = [ "--socks5-server=:1055" ];
  };

  # sfiber's socks binds :1055 (all interfaces) so the CI action sandbox in its
  # own netns can reach it. That raw --socks5-server flag bypasses the module's
  # proxyListenAddress uniqueness assertion, so it silently collides with the
  # main tailscale's default localhost:1055 — both fight over 127.0.0.1:1055 and
  # crash-loop tailscaled on boot. Move the main's socks off :1055.
  services.tailscale.proxyListenAddress = lib.mkForce "localhost:1057";

  # Our only resolver is the incus bridge dnsmasq (plain DNS), so the fleet's
  # forced DoT/DNSSEC breaks every lookup. Override the settings.Resolve keys
  # common/resolved.nix sets (the top-level options are deprecated in 26.05).
  services.resolved.settings.Resolve = {
    DNSSEC = lib.mkForce "false";
    DNSOverTLS = lib.mkForce "false";
  };

  # Remote builds copy every output closure back to this store, so it fills fast;
  # a burst once overran the hourly GC and crashed postgres. The VM is disposable
  # (durable copies live on gigabuilder), so GC hard: min/max-free keeps the
  # daemon collecting continuously, and custom-gc's target is tightened.
  nix.settings = {
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 30 * 1024 * 1024 * 1024;
  };
  garnix.custom-gc.targetPercent = 60;

  # fluent-bit's opensearch fqdn/auth come from services.garnixServer.opensearch,
  # but port/tls stay at the SaaS defaults (443 + TLS) — point them at our plain
  # local OpenSearch or every log flush fails and the UI's log view stays empty.
  garnix.fluent-bit.opensearch = {
    port = 9200;
    tls = false;
  };

  # /tmp on disk, not the fleet's 50%-RAM tmpfs: garnix runs every build and
  # microVM under /tmp, and a burst once filled the tmpfs and OOM'd the VM.
  boot.tmp = {
    useTmpfs = lib.mkForce false;
    cleanOnBoot = true;
  };

  # tag:server for the fleet's existing grants (smtp/s3/idp); tag:garnix is the
  # dedicated identity for garnix's build-offload traffic, so the kradalby.no ACL
  # can scope `src tag:garnix -> dst tag:garnix-builder` narrowly (see
  # git/infrastructure/tailscale). tag:ci is unused (garnix uses tsnixcache).
  services.tailscale.tags = [
    "tag:server"
    "tag:garnix"
  ];

  services.garnixServer = {
    enable = true;
    hostname = "garnix.kradalby.no";
    url = "https://garnix.kradalby.no"; # TLS terminated on the host
    adminGithubLogin = "kradalby";
    githubAppName = "kradalby-garnix";

    # Co-located DB + OpenSearch over loopback (plain services below): the
    # connections never leave the VM, so no TLS.
    database = {
      host = "127.0.0.1";
      port = 5432;
      ssl.mode = "disable";
    };
    opensearch = {
      url = "http://127.0.0.1:9200/_msearch";
      host = "127.0.0.1";
    };

    # Untrusted run/test steps in krun microVMs — needs /dev/kvm (nested virt).
    actionRunner.host = "127.0.0.1";

    # Offload realisation to gigabuilder (sets distributedBuilds, VM max-jobs=0);
    # outputs land in the host store that tsnixcache serves.
    remoteBuilders.hosts = [
      {
        name = "gigabuilder";
        hostname = "10.68.0.1"; # host over incusbr0 (a trustedInterface)
        user = "nix-ssh";
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 4;
        supportedFeatures = [
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
      }
      {
        # Native aarch64 builder (Ampere), so the Oracle/rpi nixosConfig checks
        # finally build instead of failing "no aarch64 builder". Reached over the
        # tailnet on a non-22 port (see Port pin below + dev.oracfurt/garnix-
        # builder.nix). maxJobs 1: small VM, and these are infrequent PR builds.
        # No kvm/nixos-test — Ampere has no /dev/kvm.
        name = "dev-oracfurt";
        hostname = "dev-oracfurt.dalby.ts.net";
        user = "nix-ssh";
        systems = [ "aarch64-linux" ];
        maxJobs = 1;
        speedFactor = 2;
        supportedFeatures = [ "big-parallel" ];
      }
      {
        # kratail2's rosetta-builder Lima VM: a fast native aarch64 builder on the
        # tailnet, PREFERRED over dev.oracfurt (higher speedFactor) whenever the
        # Mac is online. garnix does no scheduling — stock nix build-remote skips
        # an unreachable machine to the next eligible one, so an offline Mac just
        # falls back to dev.oracfurt (~5s, connect-timeout=5 from common/nix.nix +
        # the ConnectTimeout pin below). The guest runs plain tailscale (no --ssh),
        # so the nix-ssh forced-command build key works on :22 — no port pin.
        # No kvm/nixos-test through the VM.
        name = "rosetta-kratail2";
        hostname = "rosetta-kratail2.dalby.ts.net";
        user = "nix-ssh";
        systems = [ "aarch64-linux" ];
        maxJobs = 12; # VM cores
        speedFactor = 5;
        supportedFeatures = [ "big-parallel" ];
      }
    ];

    # Outputs already land in gigabuilder's tsnixcache-served store.
    s3Cache.enable = false;

    # ragenix (not sops): point every path at the decrypted secret.
    secrets = {
      databasePasswordPath = config.age.secrets.garnix-database-password.path;
      githubWebhookSecretPath = config.age.secrets.garnix-github-webhook-secret.path;
      githubClientSecretPath = config.age.secrets.garnix-github-client-secret.path;
      githubClientIdPath = config.age.secrets.garnix-github-client-id.path;
      githubAppIdPath = config.age.secrets.garnix-github-app-id.path;
      githubAppPkPath = config.age.secrets.garnix-github-app-pk.path;
      opensearchCredentialPath = config.age.secrets.garnix-opensearch-credential.path;
      jwtKeyPath = config.age.secrets.garnix-jwt-key.path;
      repoSecretsKeyPath = config.age.secrets.garnix-repo-secrets-key.path;
      repoSecretsPubKeyPath = config.age.secrets.garnix-repo-secrets-key-pub.path;
      actionRunnerSshPath = config.age.secrets.garnix-action-runner-ssh.path;
      remoteBuilderSshPath = config.age.secrets.garnix-remote-builder-ssh.path;
    };
  };

  systemd.services.garnixServer.environment = {
    GARNIX_DEFAULT_CONFIG = garnixDefaultConfig;
    # garnix's SaaS-sized pools OOM this 16 GiB VM on big repos (headscale fans
    # out ~50 evals at ~0.5 GiB each); cap them. Raise if the VM grows.
    GARNIX_NIX_EVAL_POOL_SIZE = "6";
    GARNIX_FOD_CHECK_POOL_SIZE = "4";
    # Owner allowlist (fork feature): upstream gates only by denylist, so an
    # internet-facing App builds for anyone who installs it. Unset ⇒ allow all.
    GARNIX_ALLOWED_OWNERS = "kradalby,juanfont";
  };

  # Pre-trust the builder's host key, else nix's non-interactive SSH to it fails.
  programs.ssh.knownHosts.gigabuilder = {
    hostNames = [
      "gigabuilder"
      "10.68.0.1"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfxql6LaBrlxvBDywHRWULRocO9Yo57DlrlsdDCkcis";
  };

  # dev-oracfurt's build sshd is on :2222 (tailnet :22 is Tailscale SSH). garnix
  # emits the Host alias without a Port, so pin it — ssh merges keywords across
  # matching Host blocks, taking the Port from here and the rest from garnix.
  # rosetta-kratail2 uses plain :22 (no Tailscale SSH on the guest); pin a short
  # ConnectTimeout so an offline Mac fails over to dev-oracfurt in ~5s regardless
  # of whether nix's connect-timeout maps onto the builder ssh.
  programs.ssh.extraConfig = ''
    Host dev-oracfurt
      Port 2222
    Host rosetta-kratail2
      ConnectTimeout 5
  '';
  programs.ssh.knownHosts.dev-oracfurt = {
    hostNames = [ "[dev-oracfurt.dalby.ts.net]:2222" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE65s/hRn34v5UNhSIC8/JN/452hLdqn131gVqqBTPnl";
  };

  # The guest sshd host key is generated when the Lima VM is (re)created, so it
  # rotates on any config/image change to kratail2's rosetta-builder. Read it
  # after provisioning from the Mac's working dir and paste it here:
  #   /var/lib/rosetta-builder/ssh_host_ed25519_key.pub
  # Refresh this whenever the VM is recreated (same caveat as dev-oracfurt).
  # TODO(kradalby): fill in the guest host key after first `tailscale up`.
  programs.ssh.knownHosts.rosetta-kratail2 = {
    hostNames = [ "rosetta-kratail2.dalby.ts.net" ];
    publicKey = "ssh-ed25519 AAAA_REPLACE_WITH_GUEST_HOST_KEY rosetta-kratail2";
  };

  # Loopback-only datastores, so peer/trust auth and no TLS — the fork's own
  # database/opensearch modules target separate TLS-fronted hosts, overkill here.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18; # matches garnix's migrations
    ensureDatabases = [ "garnix" ];
    ensureUsers = [
      {
        name = "garnix";
        ensureDBOwnership = true;
      }
    ];
    authentication = lib.mkForce ''
      local all all trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';
  };

  services.opensearch = {
    enable = true;
    settings = {
      "network.host" = "127.0.0.1";
      "http.port" = 9200;
      "discovery.type" = "single-node";
    };
  };

  # --- Monitoring (scraped by core.oracldn's prometheus over the tailnet) ---
  #
  # This VM is a first-class tailnet node (hostname `garnix`, tag:server), so
  # prometheus reaches every exporter directly as `garnix:<port>`. base.nix opens
  # node_exporter only on my.lan and systemd-exporter.nix opens 9558 globally;
  # rather than lean on tailscaled's implicit accept rule (fragile — see the
  # monitoring audit §2.11), open each metrics port explicitly on tailscale0.
  # Per-interface rules also survive any mkForce of the global allowedTCPPorts.
  #   9100 node_exporter · 9558 systemd_exporter · 9187 postgres_exporter
  #   8323 garnix backend metrics (module default --metrics-port, root path `/`)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    9100
    9558
    9187
    8323
  ];

  # postgres_exporter for pg_up (catches the #1 documented outage: disk fills →
  # postgres crashes into recovery → every API 500). common/postgres.nix is NOT
  # imported deliberately — it would force postgresql_14 (this VM pins _18 for the
  # garnix migrations), flip on enableTCPIP, and enable postgresqlBackup (the VM
  # is disposable, durable copies live on gigabuilder). Mirror just its exporter.
  # runAsLocalSuperUser connects over the local socket, which the trust auth above
  # accepts.
  services.prometheus.exporters.postgres = {
    enable = true;
    runAsLocalSuperUser = true;
  };

  # Give fluent-bit an HTTP server so its output-retry/health metrics exist (the
  # opensearch port/TLS flush failure has happened once, silently). The garnix
  # fork's fluent-bit module renders [SERVICE] verbatim from this attrset and sets
  # no `.service` default of its own, so re-state the shipped defaults alongside
  # the HTTP keys or they'd be dropped. Bound to loopback per the plan; a remote
  # scrape would need a tailnet-reachable bind or a proxy (see return notes).
  garnix.fluent-bit.configuration.service = {
    flush = 5;
    logLevel = "debug";
    daemon = "false";
    HTTP_Server = "On";
    HTTP_Listen = "127.0.0.1";
    HTTP_Port = 2020;
  };

  garnix.actionRunner = {
    enable = true;
    authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZOua4VBl3qw2kabW3txTxUWFVhZ09BrPMwkOjY71/s garnix-action-runner";
  };

  # The host nginx is the single public TLS terminator; make garnix's own vhost
  # plain HTTP so it doesn't chase an ACME cert it can't validate on a private IP.
  services.nginx.virtualHosts."garnix.kradalby.no" = {
    enableACME = lib.mkForce false;
    forceSSL = lib.mkForce false;
  };

  age.secrets =
    let
      s = name: { file = ../../secrets/${name}.age; };
    in
    {
      garnix-database-password = s "garnix-database-password";
      garnix-github-webhook-secret = s "garnix-github-webhook-secret";
      garnix-github-client-secret = s "garnix-github-client-secret";
      garnix-github-client-id = s "garnix-github-client-id";
      garnix-github-app-id = s "garnix-github-app-id";
      garnix-github-app-pk = s "garnix-github-app-pk";
      garnix-opensearch-credential = s "garnix-opensearch-credential";
      garnix-jwt-key = s "garnix-jwt-key";
      garnix-repo-secrets-key = s "garnix-repo-secrets-key";
      garnix-repo-secrets-key-pub = s "garnix-repo-secrets-key-pub";
      garnix-action-runner-ssh = s "garnix-action-runner-ssh";
      garnix-remote-builder-ssh = s "garnix-remote-builder-ssh";
      headscale-sfiber-ci-preauthkey = s "headscale-sfiber-ci-preauthkey";
    };

  system.stateVersion = "25.11";
}
