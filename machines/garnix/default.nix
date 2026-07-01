{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # Default build set for repos with no garnix.yaml (our fork reads
  # GARNIX_DEFAULT_CONFIG, same garnix.yaml format) — change + redeploy, no backend
  # recompile. Drops darwinConfigurations (no macOS builders); Linux
  # packages/checks/devShells + home + nixos configs still build. A repo's own
  # garnix.yaml fully overrides it.
  garnixDefaultConfig = (pkgs.formats.yaml {}).generate "garnix-default-config.yaml" {
    builds.include = [
      "*.x86_64-linux.*"
      "defaultPackage.x86_64-linux"
      "devShell.x86_64-linux"
      "homeConfigurations.*"
      "nixosConfigurations.*"
    ];
  };
in {
  # garnix CI coordinator + action-runner, running as an Incus VM on gigabuilder.
  # gigabuilder itself is the remote nix builder (see remoteBuilders below), so
  # the heavy realisation runs on bare metal in the nix sandbox while the
  # GitHub-facing / untrusted-eval / secret-holding parts stay in this guest.
  #
  # GATED: not registered in flake.nix yet (the garnix-ci input + box entry are
  # commented). Activation order is in ./GARNIX-RUNBOOK.md.
  imports = [
    ../../common/base.nix # core NixOS config: my.*, nix, users, ssh, node-exporter
    ../../common/tailscale.nix # joins the tailnet (name "garnix")
    ../../common/incus.nix # qemu-guest profile + incus agent + sda disk
    # The garnix server module (frontend + nginx + secrets + fluent-bit +
    # action-runner). Postgres + OpenSearch are SEPARATE modules in the fork
    # (nix/modules/database.nix, opensearch/nixos-module.nix) — co-locate them
    # per the DB/OpenSearch section of GARNIX-RUNBOOK.md.
    inputs.garnix-ci.nixosModules.garnix
  ];

  # The garnix modules want these specialArgs (see znaniye/garnix examples/). A
  # consumed flake exposes its resolved inputs as `.inputs`, but not `self`, so
  # graft it back on.
  _module.args.flakeInputs = inputs.garnix-ci.inputs // {self = inputs.garnix-ci;};
  _module.args.flakePackages = inputs.garnix-ci.packages.x86_64-linux;

  networking = {
    hostName = "garnix";
    domain = "fap.no";
    # Static address in the Incus VM range so the host's nginx proxy and the
    # remote-builder SSH target are stable. gw/dns is the incus bridge.
    nameservers = ["10.68.0.1"];
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

  # The fleet's common/resolved.nix forces DNSOverTLS + DNSSEC, but our only
  # resolver is the incus bridge dnsmasq (10.68.0.1, plain DNS, neither) — so
  # every lookup fails. Keep resolved (it's the sole resolv.conf writer here,
  # resolvconf is mkForce off) but drop DoT/DNSSEC.
  services.resolved.dnssec = lib.mkForce "false";
  services.resolved.dnsovertls = lib.mkForce "false";

  # Coordinator disk hygiene. gigabuilder does the building, but nix copies each
  # output closure back to THIS store (standard remote-build behaviour), so it
  # fills up — and a burst of pushes overran garnix's hourly custom-gc (it hit
  # 100% between sweeps, crashing postgres). This VM is disposable state (durable
  # copies live on gigabuilder/tsnixcache), so:
  #   - min-free/max-free makes the nix daemon GC *continuously* under pressure
  #     (closes the gap between hourly sweeps; deletes don't wear the SSD — only
  #     the copy-back writes do, and those happen regardless).
  #   - tighten custom-gc's target (garnix's own GC; it mkForce-disables nix.gc).
  nix.settings.min-free = 10 * 1024 * 1024 * 1024; # daemon GCs when free < 10 GiB
  nix.settings.max-free = 30 * 1024 * 1024 * 1024; # ...back up to 30 GiB free
  garnix.custom-gc.targetPercent = 60;

  # Ship build logs to our plain local OpenSearch. garnix-server.nix wires
  # fluent-bit's opensearch fqdn + auth from services.garnixServer.opensearch but
  # leaves port/tls at the SaaS defaults (443 + TLS), so without this fluent-bit
  # fails every flush to 127.0.0.1:443 and the build-log index stays empty — the
  # UI/raw logs read from OpenSearch, while GitHub's last-100 is captured in-band
  # (hence only the UI looked broken). Must track the opensearch.url above.
  garnix.fluent-bit.opensearch.port = 9200;
  garnix.fluent-bit.opensearch.tls = false;

  # /tmp on disk, not the fleet's 50%-RAM tmpfs (common/tmp.nix). garnix runs
  # every build, git clone and action microVM under /tmp; a burst filled the
  # tmpfs and OOM'd the VM. Clean it on boot so leaked run dirs don't pile up.
  boot.tmp.useTmpfs = lib.mkForce false;
  boot.tmp.cleanOnBoot = true;

  # tag:server only: the shared preauth key is authorized for server/builder/incus
  # but not tag:ci, so advertising ci fails the join. tag:ci only grants attic
  # access (unused here — garnix uses tsnixcache, reachable by any node via the
  # src:* → tag:cache grant). Re-add ci by regenerating the auth key with it + a
  # device_tags entry if attic is ever wanted.
  services.tailscale.tags = ["tag:server"];

  services.garnixServer = {
    enable = true;
    hostname = "garnix.kradalby.no";
    url = "https://garnix.kradalby.no"; # external URL (TLS terminated on the host)
    adminGithubLogin = "kradalby";
    githubAppName = "kradalby-garnix"; # create the App with this slug via /garnix-admin

    # Co-located DB + OpenSearch over loopback (provisioned below with plain
    # NixOS services). No TLS — the connections never leave the VM — so ssl.mode
    # is disabled rather than using garnix's TLS-fronted database.nix module.
    database = {
      host = "127.0.0.1";
      port = 5432;
      ssl.mode = "disable";
    };
    opensearch = {
      url = "http://127.0.0.1:9200/_msearch";
      host = "127.0.0.1";
    };

    # Co-located action-runner: untrusted run/test steps execute here in krun
    # microVMs. Needs /dev/kvm → the Incus VM must have nested virt enabled.
    actionRunner.host = "127.0.0.1";

    # Offload all nix realisation to the gigabuilder host. This sets
    # distributedBuilds = true and forces this VM's max-jobs = 0; built paths
    # land in the host /nix/store that tsnixcache already serves.
    remoteBuilders.hosts = [
      {
        name = "gigabuilder";
        hostname = "10.68.0.1"; # host over incusbr0 (a trustedInterface)
        user = "nix-ssh";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 4;
        supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
      }
    ];

    # Skipped: build outputs land in the gigabuilder store (via remoteBuilders)
    # that tsnixcache already serves — no separate S3 cache needed.
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

  # Default build set (defined in the `let` above) for repos with no garnix.yaml.
  systemd.services.garnixServer.environment.GARNIX_DEFAULT_CONFIG = garnixDefaultConfig;

  # Bound eval concurrency to fit this 16 GiB VM. garnix's defaults (50 evals,
  # 20 FOD checks) are tuned for garnix.io's large hosts; a big repo (headscale,
  # ~170 targets) fanned out ~50 concurrent evals (~0.5 GiB each) and OOM-killed
  # OpenSearch + nix. Builds still offload to gigabuilder (maxJobs=16); this only
  # caps the coordinator's own memory. Raise if the VM gets more RAM.
  systemd.services.garnixServer.environment.GARNIX_NIX_EVAL_POOL_SIZE = "6";
  systemd.services.garnixServer.environment.GARNIX_FOD_CHECK_POOL_SIZE = "4";

  # The remote-builder SSH (garnixServer offloads realisation to gigabuilder over
  # incusbr0) needs the builder's host key pre-trusted, else nix's non-interactive
  # SSH fails host-key verification. The module's ssh alias is `gigabuilder` →
  # 10.68.0.1.
  programs.ssh.knownHosts.gigabuilder = {
    hostNames = ["gigabuilder" "10.68.0.1"];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfxql6LaBrlxvBDywHRWULRocO9Yo57DlrlsdDCkcis";
  };

  # Co-located datastores for the backend. Loopback only, so peer/trust auth and
  # no TLS — garnix's own database.nix/opensearch modules target separate
  # TLS-fronted hosts (ACME cert per fqdn, nginx+basic-auth) and are overkill
  # here. The garnix-* secrets for db/opensearch are still staged by the server
  # module but go unused with trust auth.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18; # matches what garnix's migrations expect
    ensureDatabases = ["garnix"];
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

  # The garnix runner authorizes the coordinator's key; public half of
  # garnix-action-runner-ssh.
  garnix.actionRunner.enable = true;
  garnix.actionRunner.authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZOua4VBl3qw2kabW3txTxUWFVhZ09BrPMwkOjY71/s garnix-action-runner";

  # The host nginx (machines/gigabuilder/web.nix) is the single public TLS
  # terminator. Make garnix's own vhost serve plain HTTP so it does NOT try to
  # get its own ACME cert (which can't validate on the private VM IP). devMode
  # would also drop SSL but disables remoteBuilders, so override the vhost
  # directly instead.
  services.nginx.virtualHosts."garnix.kradalby.no" = {
    enableACME = lib.mkForce false;
    forceSSL = lib.mkForce false;
  };

  age.secrets = let
    s = name: {file = ../../secrets/${name}.age;};
  in {
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
  };

  system.stateVersion = "25.11";
}
