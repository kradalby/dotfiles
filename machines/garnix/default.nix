{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
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

  services.tailscale.tags = ["tag:ci" "tag:server"];

  services.garnixServer = {
    enable = true;
    hostname = "garnix.kradalby.no";
    url = "https://garnix.kradalby.no"; # external URL (TLS terminated on the host)
    adminGithubLogin = "kradalby";
    # githubAppName = "kradalby-garnix"; # set to the GitHub App slug once created

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

    s3Cache.enable = false; # start simple; revisit tsnixcache/MinIO sharing later

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
  # garnix.actionRunner.authorizedKey = "<public half of garnix-action-runner-ssh>";

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
