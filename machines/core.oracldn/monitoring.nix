{
  pkgs,
  config,
  lib,
  ...
}: let
  # All NixOS hosts reachable via Tailscale
  # These all have node_exporter and systemd_exporter enabled
  allHosts = [
    "core-oracldn"
    # "core-terra"
    "core-tjoda"
    "dev-oracfurt"
    "dev-ldn"
    "home-ldn"
    "storage-ldn"
    "gigabuilder"
    "ts1p-ldn"
    "garnix"
  ];

  # Hosts running the postfix relay + its exporter (port 9154). These import
  # profiles/server.nix; ts1p-ldn and garnix are base.nix-only (no postfix), so
  # scraping them for postfix would be a permanent ExporterDown.
  serverHosts = [
    "core-oracldn"
    "core-tjoda"
    "dev-oracfurt"
    "dev-ldn"
    "home-ldn"
    "storage-ldn"
    "gigabuilder"
  ];

  # Hosts with ZFS pools (have zfs_exporter enabled)
  zfsHosts = [
    # "core-terra"
    "core-tjoda"
    "storage-ldn"
    "gigabuilder"
  ];

  # Hosts with smartctl monitoring enabled
  smartctlHosts = [
    "core-tjoda"
    "gigabuilder"
  ];

  # Hosts with smokeping exporter
  smokepingHosts = [
    # "core-terra"
    "core-tjoda"
  ];

  # Hosts running CoreDNS (prometheus on :9153)
  corednsHosts = [
    "core-oracldn"
    "core-tjoda"
    "storage-ldn"
  ];

  # Hosts running Nginx with nginxlog exporter (port 9117)
  nginxlogHosts = [
    "core-oracldn"
    # "core-terra"
    "gigabuilder"
  ];

  # Restic REST server Tailscale service names
  resticHosts = [
    "restic-tjoda"
    "restic-ldn"
    # "restic-terra"
  ];

  blackboxConfigFile = pkgs.writeText "blackbox.conf" ''
    modules:
      http_prometheus:
        prober: http
        timeout: 5s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          ip_protocol_fallback: false
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          valid_status_codes: [200, 301, 302]
          enable_http2: false
          fail_if_ssl: false
          fail_if_not_ssl: true
          tls_config:
            insecure_skip_verify: false
      icmp:
        prober: icmp
        timeout: 10s
        icmp:
          preferred_ip_protocol: ip4
      # Tailnet-only services: tsnet/Serve certs, and 401/403 count as alive
      # (auth-gated endpoints like garnix /api/whoami).
      http_tailnet:
        prober: http
        timeout: 5s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          ip_protocol_fallback: false
          valid_status_codes: [200, 301, 302, 401, 403]
          fail_if_ssl: false
          fail_if_not_ssl: false
      # restic REST endpoints answer 400 on / (verified against the live
      # rclone serve restic) — any HTTP status proves the VIP → daemon path
      # (a dead backend is a connection error, not a status code).
      http_restic:
        prober: http
        timeout: 5s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          ip_protocol_fallback: false
          valid_status_codes: [200, 400, 404, 405]
          fail_if_ssl: false
          fail_if_not_ssl: false
      # End-to-end DNS through each site's CoreDNS resolver.
      dns:
        prober: dns
        timeout: 5s
        dns:
          query_name: "kradalby.no"
          query_type: "A"
          transport_protocol: "udp"
          preferred_ip_protocol: ip4
      tcp_connect:
        prober: tcp
        timeout: 5s
        tcp:
          preferred_ip_protocol: ip4
  '';

  # Filesystem filter for disk alerts — excludes virtual, boot, and Incus
  # filesystems. Incus guests have dedicated alerts (role="incus"), but the
  # Incus *host* carries no role label, so two host-side mounts leak through and
  # storm on every build spike: /var/lib/lxcfs (fuse.lxcfs always reports 0 free)
  # and the per-VM /var/lib/incus/devices/*.mount config datasets (~500MB ZFS
  # metadata, not the real VM disk). Exclude both by fstype and mountpoint.
  diskFilter = ''fstype!~"(tmpfs|ramfs|fuse.lxcfs)",mountpoint!~"^/boot.?/?.*",mountpoint!~"^/var/lib/incus/devices/.*",role!="incus"'';

  # Every job carries a port-free "host" label so Alertmanager can group and
  # inhibit per machine; the instance label includes the port, which made the
  # inhibit rules' equal=["instance"] never match across exporters.
  hostRelabel = {
    source_labels = ["__address__"];
    regex = "([^:]+):?.*";
    target_label = "host";
  };

  # Helper for blackbox probe jobs: probe each target through the local
  # blackbox exporter with the given module.
  probeJob = name: module: targets: {
    job_name = name;
    metrics_path = "/probe";
    params.module = [module];
    static_configs = [{inherit targets;}];
    relabel_configs = [
      {
        source_labels = ["__address__"];
        target_label = "__param_target";
      }
      {
        source_labels = ["__param_target"];
        target_label = "instance";
      }
      {
        target_label = "__address__";
        replacement = "127.0.0.1:9115";
      }
    ];
  };

  # Helper to create a simple scrape job with /metrics path
  scrapeJob = name: targets: {
    job_name = name;
    metrics_path = "/metrics";
    static_configs = [{inherit targets;}];
    relabel_configs = [hostRelabel];
  };

  # Helper to create scrape jobs for exporters across multiple hosts
  # Takes a job name, list of hostnames, and port number
  exporterJob = name: hosts: port: {
    job_name = name;
    metrics_path = "/metrics";
    static_configs = [
      {
        targets = map (host: "${host}:${toString port}") hosts;
      }
    ];
    relabel_configs = [hostRelabel];
  };
in {
  # tcp:443 endpoints have no TLS termination — Tailscale VIP bug
  # (tailscale/tailscale#19724, #18381); consumers use http.
  # TODO(kradalby): revert when fixed.
  services.tailscale.services = {
    prom = {
      endpoints = {
        "tcp:80" = "http://localhost:${toString config.services.prometheus.port}";
        "tcp:443" = "http://localhost:${toString config.services.prometheus.port}";
      };
    };
    alertmanager = {
      endpoints = {
        "tcp:80" = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
        "tcp:443" = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
      };
    };
    pushgateway = {
      endpoints = {
        "tcp:80" = "http://${config.services.prometheus.pushgateway.web.listen-address}";
        "tcp:443" = "http://${config.services.prometheus.pushgateway.web.listen-address}";
      };
    };
  };

  age.secrets.alertmanager-env = {
    file = ../../secrets/alertmanager-env.age;
    owner = config.systemd.services.prometheus.serviceConfig.User;
  };

  services.prometheus = {
    enable = true;

    retentionTime = "365d";
    webExternalUrl = "http://prom/";

    globalConfig = {
      external_labels = {
        cluster = "homelab";
        site = "oracldn";
      };
    };

    alertmanagers = [
      {
        scheme = "http";
        path_prefix = "/";
        static_configs = [
          {targets = ["localhost:${toString config.services.prometheus.alertmanager.port}"];}
        ];
      }
    ];

    scrapeConfigs = [
      # Node exporter on all hosts (port 9100)
      (exporterJob "nodes" allHosts 9100)

      # Systemd exporter on all hosts (port 9558)
      (exporterJob "systemd" allHosts 9558)

      # ZFS exporter on hosts with ZFS pools (port 9134)
      (exporterJob "zfs" zfsHosts 9134)

      # Smartctl exporter on hosts with disk monitoring (port 9633)
      (exporterJob "smartctl" smartctlHosts 9633)

      # Smokeping exporter (port 9374)
      (exporterJob "smokeping" smokepingHosts 9374)

      # CoreDNS metrics (port 9153)
      (exporterJob "coredns" corednsHosts 9153)

      # Nginx log exporter (port 9117)
      (exporterJob "nginxlog" nginxlogHosts 9117)

      # MQTT exporter on home-ldn (port 9000)
      (scrapeJob "mqtt" ["home-ldn:9000"])

      # Restic REST server metrics (via Tailscale service names)
      {
        job_name = "restic-server";
        metrics_path = "/metrics";
        static_configs = [
          {targets = map (h: "${h}:80") resticHosts;}
        ];
        relabel_configs = [hostRelabel];
      }

      # rclone serve restic (Jotta proxy) on core.tjoda: core transfer stats
      # only — no per-repo series like rest-server (rclone#7980). Target-down
      # is covered by the generic up==0 alert; the traffic cross-check and
      # metric-rename canary live in the backup rules below.
      (scrapeJob "rclone-jotta" ["core-tjoda:56901"])

      # Pushgateway: backup success timestamps, sfiber proxy state, rustic
      # laptops — anything Prometheus has no route into pushes here.
      # honor_labels keeps the pushed instance/job labels intact. Scraped
      # locally; producers push in over the svc:pushgateway VIP (ACL-scoped
      # to tag:monitoring in ~/git/infrastructure).
      {
        job_name = "pushgateway";
        metrics_path = "/metrics";
        honor_labels = true;
        static_configs = [{targets = ["localhost:9091"];}];
      }

      # ICMP ping of every scraped host over the tailnet. Splits "host is
      # dead" from "exporter/firewall is broken" in the node alerts below.
      {
        job_name = "tailnet-ping";
        metrics_path = "/probe";
        params = {
          module = ["icmp"];
        };
        static_configs = [{targets = allHosts;}];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            source_labels = ["__param_target"];
            target_label = "host";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }

      # Incus hypervisor metrics (per-VM instance + host node_exporter)
      # Requires: incus config set core.metrics_authentication false
      {
        job_name = "incus";
        scrape_interval = "30s"; # Incus metric collection is expensive, 8s cache
        metrics_path = "/1.0/metrics";
        scheme = "https";
        tls_config = {
          # Self-signed cert, connection is over Tailscale
          insecure_skip_verify = true;
        };
        static_configs = [
          {
            # core-ldn (IncusOS) also passes through host node_* series;
            # gigabuilder (nixpkgs incus) exports incus_* only.
            targets = ["core-ldn:8443" "gigabuilder:8443"];
            labels.role = "incus";
          }
        ];
        relabel_configs = [hostRelabel];
      }

      # tsnixcache: fleet nix cache AND the only GC on gigabuilder's store.
      # tsnet node; private registry (no go_*/process_* series).
      (scrapeJob "tsnixcache" ["tsnixcache:80"])

      # Application-specific exporters
      # OCI usage exporter binds localhost on this host, no ACL needed
      (scrapeJob "oci-usage" ["localhost:63461"])
      (scrapeJob "litestream" ["core-oracldn:54909" "dev-oracfurt:54909"])
      (scrapeJob "headscale" ["core-oracldn:54910"])

      # atuin shell-history sync server on dev.oracfurt (native metrics).
      # up{job="atuin"} feeds the generic scrape-success burn-rate SLO.
      (scrapeJob "atuin" ["dev-oracfurt:8889"])

      # Monitoring must watch itself; the Watchdog/dead-man covers the rest.
      (scrapeJob "prometheus" ["localhost:9090"])
      (scrapeJob "alertmanager" ["localhost:9093"])

      # Syncthing native metrics via the GUI tailscale services
      # (insecureAdminAccess, no creds). :81 on dev-oracfurt is the cooklang
      # instance. This scrape is itself the liveness check.
      (scrapeJob "syncthing" [
        "syncthing-dev-oracfurt:80"
        "syncthing-cooklang:80"
        "syncthing-ldn:80"
        "syncthing-tjoda:80"
        "syncthing-dev-ldn:80"
      ])

      # Garage metrics (litestream's replica target, tjoda only), on the
      # admin API via the s3-tjoda VIP; /metrics is public (no metrics_token).
      {
        job_name = "garage";
        static_configs = [{targets = ["s3-tjoda:3903"];}];
        relabel_configs = [hostRelabel];
      }

      # PostgreSQL exporter (port 9187)
      (scrapeJob "postgres" ["core-oracldn:9187" "garnix:9187"])

      # garnix CI backend: native prometheus text on the ROOT path at :8323
      # (prometheusApp [] — /metrics 404s). Queue gauges are NEGATIVE when
      # idle (free slots) and positive when backlogged.
      {
        job_name = "garnix";
        metrics_path = "/";
        static_configs = [{targets = ["garnix:8323"];}];
        relabel_configs = [hostRelabel];
      }

      # Postfix queue depth on the fleet relay. gigabuilder is the only host
      # running postfix now — every other machine uses send-only nullmailer
      # (no queue exporter), so a stuck-mail signal only exists here.
      (exporterJob "postfix" ["gigabuilder"] 9154)

      # tailscaled usermetrics via the web client listener, fleet-wide.
      # Requires a tailnet ACL grant for tcp:5252 from this host (out-of-band).
      (exporterJob "tailscaled" allHosts 5252)

      # Native app metrics over tailnet names. krapage/hvor/nefit expose only
      # go runtime series — up{} liveness is the honest signal there.
      (scrapeJob "grafana" ["localhost:3000"])
      (scrapeJob "krapage" ["krapage:80"])
      (scrapeJob "hvor" ["hvor:80"])
      (scrapeJob "homekit-bridges" [
        "nefit-homekit:80"
        "tasmota-homekit:80"
        "z2m-homekit:80"
      ])

      # golink: note the leading dot in the path; https with a ts.net cert.
      # Full FQDN target so the ts.net cert validates (the cert is for
      # go.dalby.ts.net; the bare "go" name failed x509 SAN verification).
      {
        job_name = "golink";
        scheme = "https";
        metrics_path = "/.metrics";
        static_configs = [{targets = ["go.dalby.ts.net:443"];}];
        relabel_configs = [hostRelabel];
      }

      # ts1p (setec) secrets server. Assumes the fork exposes varz.Handler at
      # an un-gated /metrics (only ts1p_* counters, no secret material). Full
      # FQDN target so the ts.net cert validates. Reaching it needs the tcp:443
      # tailnet ACL to setec.
      {
        job_name = "ts1p";
        scheme = "https";
        metrics_path = "/metrics";
        static_configs = [{targets = ["setec.dalby.ts.net:443"];}];
        relabel_configs = [hostRelabel];
      }

      # uptime-kuma: /metrics is auth-gated and the UI is public (nginx +
      # ACME), so disabling auth to scrape it is unsafe. We watch liveness via
      # the public https probe below; kuma notifies on its own monitors.

      # Service-level probes: "does it respond at all", one tier per exposure.
      #
      # Tailscale VIP tcp:443 does NOT TLS-terminate — an https probe hits a bare
      # HTTP backend ("http response to https client"). These VIPs are http-only
      # until upstream fixes it:
      #   https://github.com/tailscale/tailscale/issues/19724
      #   https://github.com/tailscale/tailscale/issues/18381
      # TODO(kradalby): revert grafana/cook/pdf/paseo/owntone to https
      # once resolved. idp + setec stay https — they are tsnet apps that
      # terminate TLS themselves, not services.tailscale.services passthrough.
      (probeJob "tailnet-probes" "http_tailnet" [
        "http://grafana.dalby.ts.net"
        "https://idp.dalby.ts.net/.well-known/openid-configuration"
        "https://setec.dalby.ts.net/healthz"
        "http://cook.dalby.ts.net"
        "http://pdf.dalby.ts.net"
        "http://atuin.dalby.ts.net"
        "http://go.dalby.ts.net"
        "http://paseo-dev-ldn.dalby.ts.net"
        "http://dev-ldn:8846"
        "http://owntone.dalby.ts.net"
        "http://s3-tjoda:3903/health"
      ])

      # The Jotta offsite path: VIP → rclone serve restic on core.tjoda. Every
      # fleet host's only offsite copy rides this endpoint, so it gets its own
      # probe and alert rather than the generic tailnet tier.
      (probeJob "restic-jotta-probe" "http_restic" [
        "http://restic-jotta.dalby.ts.net"
      ])

      # Per-site labels so a resolver-down alert can inhibit that site's
      # downstream name-resolution-dependent probes (see inhibit_rules).
      ((probeJob "dns-probes" "dns" [])
        // {
          static_configs = [
            {
              targets = ["10.66.0.1"];
              labels.site = "oracldn";
            }
            {
              targets = ["10.62.0.2"];
              labels.site = "tjoda";
            }
            {
              targets = ["10.65.0.28"];
              labels.site = "ldn";
            }
          ];
        })
      (probeJob "tcp-probes" "tcp_connect" [
        "proton-bridge:143"
        "core-tjoda:445"
        "storage-ldn:445"
      ])

      # Watch the dead-man's own egress path. The Watchdog + litestream
      # heartbeat ping hc-ping.com (the hosted healthchecks.io ping host — a
      # SEPARATE domain from the healthchecks.io dashboard); if THIS box loses
      # its route there (DNS, egress firewall, provider outage) the out-of-band
      # notifier goes blind while we still look healthy. Probing the actual
      # ping host means a broken transport pages via Discord now, instead of
      # surfacing 15m later as a missed ping. Own job (not https-probes) so it
      # stays warning, not a critical page for someone else's downtime.
      (probeJob "deadman-transport" "http_prometheus" ["https://hc-ping.com"])

      # Blackbox HTTPS probing for public endpoints
      {
        job_name = "https-probes";
        metrics_path = "/probe";
        params = {
          module = ["http_prometheus"];
        };
        static_configs = [
          {
            targets = [
              # /health pings the headscale DB and 500s on failure; probing /
              # only exercised a static 200 handler.
              "https://headscale.kradalby.no/health"
              "https://uptime.kradalby.no"
              "https://kradalby.no"
              "https://umami.kradalby.no"
              "https://hvor.kradalby.no?from=discord"
              # garnix CI edge; its documented failure mode (disk full →
              # postgres recovery loop → 500s) fails this probe.
              "https://garnix.kradalby.no"
            ];
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }

      # Blackbox ICMP probing for Tjoda devices
      {
        job_name = "tjoda-ping";
        metrics_path = "/probe";
        params = {
          module = ["icmp"];
        };
        static_configs = [
          {
            # site label lets a tjoda-resolver DnsProbeDown inhibit this whole
            # job — the targets are *.tjoda.fap.no and can't resolve when the
            # resolver is unreachable, so the pings fail as a downstream effect.
            labels.site = "tjoda";
            targets = [
              # Unifi
              "hus-kontor-printer.tjoda.fap.no"
              "love-kontor-printer.tjoda.fap.no"
              "hus-kontor-switch.tjoda.fap.no"
              "love-loft-switch.tjoda.fap.no"
              "love-kontor-switch.tjoda.fap.no"
              "love-scene-switch.tjoda.fap.no"
              "bryggerhus-switch.tjoda.fap.no"
              "hus-kontor-ap.tjoda.fap.no"
              "hus-spisestue-ap.tjoda.fap.no"
              "love-scene-ap.tjoda.fap.no"
              "love-selskap-ap.tjoda.fap.no"
              "love-lager-ap.tjoda.fap.no"
              "bryggerhus-ap.tjoda.fap.no"

              # Sonos hus
              # "hus-kjokken-sonos.tjoda.fap.no"
              # "hus-salong-sonos.tjoda.fap.no"
              # "hus-spisestue-sonos.tjoda.fap.no"
              # "hus-kontor-sonos.tjoda.fap.no"
              # "hus-gang-sonos.tjoda.fap.no"
              # "hus-hage-sonos.tjoda.fap.no"

              # Sonos låve
              # "love-kontor-bridge-sonos.tjoda.fap.no"
              # "love-salong-sonos.tjoda.fap.no"
              # "love-spisestue-sonos.tjoda.fap.no"
              # "love-dansegulv-sonos.tjoda.fap.no"
              # "love-loft-sonos.tjoda.fap.no"

              # Atlas probe
              "atlas-probe.tjoda.fap.no"
            ];
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }

      # Tasmota smart plugs
      {
        job_name = "tasmota";
        metrics_path = "/probe";
        scrape_interval = "10s";
        static_configs = [
          {
            targets = [
              "living-room-corner.ldn"
              "living-room-shelf.ldn"
              "living-room-drawer.ldn"
              "living-room-sofa.ldn"
              "office-light.ldn"
              "office-air.ldn"
              "living-room-tv.ldn"
              "office-fridge.ldn"
              "office-workstation.ldn"
              "office-fan-heater.ldn"
              "staircase-servers.ldn"
            ];
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:63459";
          }
        ];
      }

      # HomeWizard P1 smart meter
      {
        job_name = "homewizard";
        metrics_path = "/probe";
        scrape_interval = "10s";
        static_configs = [
          {
            targets = ["power-p1-meter.ldn"];
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:63460";
          }
        ];
      }
    ];

    rules = [
      (builtins.toJSON {
        groups = [
          # Node/host-level alerts
          {
            name = "node";
            rules = [
              {
                alert = "ExporterDown";
                expr = ''up{job!="nodes"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Exporter {{ $labels.job }} down on {{ $labels.instance }}";
                  description = "The {{ $labels.job }} exporter on {{ $labels.instance }} has been unreachable for more than 5 minutes.";
                };
              }
              {
                alert = "NodeExporterDown";
                # "unless ping ok" (not "and ping failed") so this still fires
                # if the blackbox exporter itself is dead.
                expr = ''up{job="nodes"} == 0 unless on (host) probe_success{job="tailnet-ping"} == 1'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Host {{ $labels.host }} is unreachable";
                  description = "Node exporter is down and the host does not answer ping over the tailnet. Is it powered on? Is Tailscale running?";
                };
              }
              {
                alert = "HostUpScrapeBroken";
                expr = ''up{job="nodes"} == 0 and on (host) probe_success{job="tailnet-ping"} == 1'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }} answers ping but its node exporter is unreachable";
                  description = "The host is alive but the scrape fails — exporter crashed or a firewall change closed the port (check interfaces.tailscale0.allowedTCPPorts).";
                };
              }
              {
                alert = "InstanceLowDiskAbs";
                expr = ''node_filesystem_avail_bytes{${diskFilter}} / 1024 / 1024 < 1024'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}MB free on {{ $labels.device }} @ {{ $labels.mountpoint }}";
                  description = "Less than 1GB of free disk space left on {{ $labels.mountpoint }}.";
                };
              }
              (
                let
                  low_megabyte = 70;
                in {
                  alert = "InstanceLowBootDiskAbs";
                  expr = ''node_filesystem_avail_bytes{mountpoint=~"^/boot.?/?.*"} / 1024 / 1024 < ${toString low_megabyte}'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.instance }}: {{ $value }}MB free on {{ $labels.device }} @ {{ $labels.mountpoint }}";
                    description = "Less than ${toString low_megabyte}MB of free disk space left on a boot filesystem. A single kernel consumes ~40MB.";
                  };
                }
              )
              {
                alert = "InstanceLowDiskPerc";
                expr = ''100 * (node_filesystem_avail_bytes{${diskFilter}} / node_filesystem_size_bytes{${diskFilter}}) < 10'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}% free on {{ $labels.device }}";
                  description = "Less than 10% of free disk space left on {{ $labels.mountpoint }}.";
                };
              }
              {
                alert = "InstanceLowDiskPrediction12Hours";
                expr = ''predict_linear(node_filesystem_free_bytes{${diskFilter}}[3h],12 * 3600) < 0'';
                for = "2h";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} ({{ $labels.device }}) will be full in <12h";
                  description = "Disk {{ $labels.mountpoint }} ({{ $labels.device }}) on {{ $labels.instance }} is predicted to fill within 12 hours based on the last 3 hours of data.";
                };
              }
              {
                alert = "InstanceLowMem";
                expr = ''node_memory_MemAvailable_bytes{job!="incus"} / 1024 / 1024 < node_memory_MemTotal_bytes{job!="incus"} / 1024 / 1024 / 10'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}% memory available";
                  description = "Less than 10% of memory available for more than 30 minutes.";
                };
              }
              {
                alert = "HighCPULoad";
                expr = ''node_load15 > count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: 15m load average {{ $value }} exceeds CPU count";
                  description = "The 15-minute load average on {{ $labels.instance }} has exceeded the number of CPUs for more than 15 minutes.";
                };
              }
              {
                alert = "OOMKill";
                expr = "increase(node_vmstat_oom_kill[1h]) > 0";
                for = "1m";
                labels.severity = "critical";
                annotations = {
                  summary = "OOM kill detected on {{ $labels.instance }}";
                  description = "A process was killed by the OOM killer on {{ $labels.instance }} in the last hour.";
                };
              }
            ];
          }

          # Systemd service alerts
          {
            name = "systemd";
            rules = [
              {
                alert = "ServiceFailed";
                expr = ''systemd_unit_state{state="failed"} > 0'';
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: service {{ $labels.name }} failed";
                  description = "The systemd unit {{ $labels.name }} on {{ $labels.instance }} has been in failed state for more than 2 minutes.";
                };
              }
              {
                alert = "ServiceFlapping";
                # The old 5m branch was dead code: at a 1m scrape interval a
                # 5m window holds ≤5 samples, so changes() can never exceed 5.
                expr = ''changes(systemd_unit_state{state="failed"}[1h]) > 15'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: service {{ $labels.name }} is flapping";
                  description = "The systemd unit {{ $labels.name }} has changed failed-state more than 15 times in the last hour.";
                };
              }
              {
                alert = "ServiceRestartLoop";
                # State sampling at 1m misses fast restart loops entirely;
                # the restart counter does not.
                expr = ''increase(systemd_service_restart_total[15m]) > 3'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: {{ $labels.name }} restarted {{ $value }} times in 15m";
                  description = "The service is crash-looping (Restart=always hides this from failed-state alerts).";
                };
              }
              {
                alert = "SystemdUnitActivatingTooLong";
                # Oneshot backup jobs report "activating" for their entire
                # runtime; hourly restic uploads routinely exceed 5m. They get
                # their own long fuse below instead of training alert-blindness.
                expr = ''systemd_unit_state{state="activating",name!~"restic-backups-.*\\.service|postgresqlBackup-.*\\.service"} == 1'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: unit {{ $labels.name }} stuck activating";
                  description = "The systemd unit {{ $labels.name }} has been in activating state for more than 5 minutes.";
                };
              }
              {
                alert = "BackupJobRunningTooLong";
                expr = ''systemd_unit_state{state="activating",name=~"restic-backups-.*\\.service|postgresqlBackup-.*\\.service"} == 1'';
                for = "6h";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: backup job {{ $labels.name }} running for over 6h";
                  description = "A backup unit has been running far longer than any normal upload; it is probably wedged.";
                };
              }
              {
                alert = "PushgatewayGroupStale";
                # Rustic laptops are excluded: they legitimately go offline for
                # days (travel) and have their own 3-day RusticBackupStale rule.
                expr = ''time() - push_time_seconds{job!="rustic"} > 86400'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "Stale pushgateway group: {{ $labels.job }}/{{ $labels.instance }}";
                  description = "Nothing has pushed to this pushgateway group for over a day; the producer (backup wrapper, proxy check) has gone quiet.";
                };
              }
            ];
          }

          # ZFS storage alerts
          {
            name = "zfs";
            rules = [
              {
                alert = "ZFSPoolMissing";
                expr = ''up{job="zfs"} == 1 unless on(instance) zfs_pool_health'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS exporter up but no pools found on {{ $labels.instance }}";
                  description = "The ZFS exporter on {{ $labels.instance }} is responding but reports no pool health metrics. This could indicate a disk failure or import issue.";
                };
              }
              {
                alert = "ZFSPoolUnhealthy";
                expr = "zfs_pool_health != 0";
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} unhealthy on {{ $labels.instance }}";
                  description = "The ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is in a degraded or faulted state.";
                };
              }
              {
                alert = "ZFSPoolSpaceWarning";
                expr = "(zfs_pool_allocated_bytes / zfs_pool_size_bytes) * 100 > 80";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $value }}% full";
                  description = "ZFS pool {{ $labels.pool }} is above 80% capacity. ZFS performance degrades significantly above this threshold.";
                };
              }
              {
                alert = "ZfsSnapshotStale";
                # From the sanoid textfile exporter; 0 (never/parse failure)
                # also fires. 25h of slack over the daily cadence.
                expr = ''time() - zfs_snapshot_newest_creation_seconds > 90000'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "Newest snapshot of {{ $labels.dataset }} on {{ $labels.host }} is stale";
                  description = "sanoid has not produced a snapshot for over 25 hours; snapshotting has silently stalled.";
                };
              }
              {
                alert = "ZpoolStatusErrors";
                expr = ''zfs_pool_status_errors == 1'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "zpool status reports errors on {{ $labels.pool }} ({{ $labels.host }})";
                  description = "The pool is accumulating checksum/scrub errors while staying ONLINE — zfs_pool_health alone does not catch this.";
                };
              }
              {
                alert = "TimeMachineFlatline";
                # written_bytes rather than delta(used): TM thinning makes
                # `used` non-monotonic.
                expr = ''max_over_time(zfs_dataset_written_bytes{name=~".*timemachine.*"}[7d]) == 0'';
                labels.severity = "warning";
                annotations = {
                  summary = "No Time Machine writes to {{ $labels.name }} for 7 days";
                  description = "A laptop has silently stopped backing up over samba, or the share is broken.";
                };
              }
              {
                alert = "ZFSPoolSpaceCritical";
                expr = "(zfs_pool_allocated_bytes / zfs_pool_size_bytes) * 100 > 90";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $value }}% full";
                  description = "ZFS pool {{ $labels.pool }} is above 90% capacity. Immediate action required.";
                };
              }
            ];
          }

          # SMART disk health alerts
          {
            name = "smartctl";
            rules = [
              {
                alert = "SMARTDiskUnhealthy";
                expr = "smartctl_device_smart_status != 1";
                for = "1m";
                labels.severity = "critical";
                annotations = {
                  summary = "SMART reports disk {{ $labels.device }} unhealthy on {{ $labels.instance }}";
                  description = "SMART self-assessment on {{ $labels.device }} ({{ $labels.model_name }}) indicates the disk is failing.";
                };
              }
              {
                alert = "SmartctlDiskMissing";
                # core.tjoda monitors 5 disks by ID (machines/core.tjoda/
                # default.nix); a disk vanishing from the exporter is itself a
                # failure signal, not a reason for silence.
                expr = ''count by (host) (smartctl_device_smart_status{host="core-tjoda"}) < 5'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.host }}: only {{ $value }}/5 disks report SMART";
                  description = "A monitored disk disappeared from the smartctl exporter — dead disk, dead controller, or the by-id list is stale.";
                };
              }
              {
                alert = "SMARTDiskTemperature";
                expr = ''smartctl_device_temperature{temperature_type="current"} > 55'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Disk {{ $labels.device }} on {{ $labels.instance }} is {{ $value }}C";
                  description = "Disk temperature on {{ $labels.device }} ({{ $labels.model_name }}) has been above 55C for more than 15 minutes.";
                };
              }
            ];
          }

          # Network and connectivity alerts
          {
            name = "network";
            rules = [
              {
                alert = "TjodaPingDown";
                expr = ''probe_success{job="tjoda-ping"} == 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Tjoda device {{ $labels.instance }} unreachable for 10m";
                  description = "A device in Tjodalyng (typically Unifi networking or Sonos) has not responded for over 10 minutes.";
                };
              }
              {
                alert = "HttpsProbeDown";
                expr = ''probe_success{job="https-probes"} == 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "HTTPS probe failed for {{ $labels.instance }}";
                  description = "The public HTTPS endpoint {{ $labels.instance }} has been unreachable or returning errors for more than 5 minutes.";
                };
              }
              {
                alert = "TailnetServiceDown";
                expr = ''probe_success{job=~"tailnet-probes|tcp-probes"} == 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Tailnet service {{ $labels.instance }} not responding";
                  description = "Convenience-tier service is down: dead tsnet node, expired node key, broken Serve mapping, or the backend itself.";
                };
              }
              {
                alert = "DeadmanNotifierUnreachable";
                expr = ''probe_success{job="deadman-transport"} == 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "core.oracldn cannot reach hc-ping.com";
                  description = "The Watchdog and litestream heartbeat cannot ping the out-of-band dead-man; if the pipeline dies now, nothing will notice. Check egress/DNS, or healthchecks.io status.";
                };
              }
              {
                alert = "TailscaledRouteApprovalPending";
                # Advertised routes that were never approved (e.g. after a
                # gateway re-auth): LAN/subnet sites become unreachable while
                # every other signal stays green. Both gauges are registered at
                # startup (source-verified, ipn/ipnlocal/local.go) so they read 0
                # on non-routers — the expr self-selects the subnet routers.
                # Needs the tcp:5252 tailnet ACL for the tailscaled scrape.
                expr = ''tailscaled_advertised_routes - tailscaled_approved_routes > 0'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.host }}: {{ $value }} advertised route(s) not approved";
                  description = "A subnet router is advertising routes the control plane has not approved; the LAN/subnet behind it is unreachable over the tailnet.";
                };
              }
              {
                alert = "CorednsUpstreamBroken";
                # Single counter, no `to` label — earliest all-upstreams-down
                # signal; the 1h cache masks outages for cached names.
                expr = ''increase(coredns_forward_healthcheck_broken_total[10m]) > 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "CoreDNS on {{ $labels.host }} lost all upstreams";
                  description = "All DNS forward upstreams are failing health checks; resolution runs on cache fumes.";
                };
              }
              {
                alert = "ProtonBridgeLoginFailing";
                expr = ''proton_bridge_login_ok == 0'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "protonmail-bridge on dev-oracfurt rejects IMAP login";
                  description = "The bridge is signed out or broken — the fleet's outgoing mail path (and the email alert fallback) is dead until someone re-runs `protonmail-bridge --cli` login.";
                };
              }
              {
                alert = "PostfixQueueBacklog";
                expr = ''postfix_showq_message_size_bytes_count{queue="deferred"} > 100'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: {{ $value }} deferred mails in the postfix queue";
                  description = "The relay path (smtp.fap.no / proton bridge) is failing; alert emails and cron mail are silently piling up.";
                };
              }
              {
                alert = "DnsProbeDown";
                expr = ''probe_success{job="dns-probes"} == 0'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "CoreDNS resolver {{ $labels.instance }} failing end-to-end queries";
                  description = "LAN clients at this site cannot resolve; note the 1h cache can mask this for cached names.";
                };
              }
              {
                alert = "SmartPlugTelemetryDown";
                # These exporters emit per-target probe_success; their up{}
                # stays 1 when subnet-route forwarding breaks — that's the bug.
                expr = ''probe_success{job=~"tasmota|homewizard"} == 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "No response from {{ $labels.instance }}";
                  description = "Smart plug / P1 meter unreachable — device offline or the LDN subnet route is broken.";
                };
              }
              {
                alert = "TlsCertExpiringSoon";
                expr = ''probe_ssl_earliest_cert_expiry{job="https-probes"} - time() < 14 * 86400'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "TLS cert for {{ $labels.instance }} expires in less than 14 days";
                  description = "The TLS certificate for {{ $labels.instance }} will expire soon. Check ACME renewal.";
                };
              }
              {
                alert = "TlsCertExpiryCritical";
                expr = ''probe_ssl_earliest_cert_expiry{job="https-probes"} - time() < 3 * 86400'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "TLS cert for {{ $labels.instance }} expires in less than 3 days";
                  description = "The TLS certificate for {{ $labels.instance }} is about to expire. ACME renewal may be broken.";
                };
              }
              {
                alert = "NetworkInterfaceErrors";
                expr = "rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 0";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Network errors on {{ $labels.device }} ({{ $labels.instance }})";
                  description = "Network interface {{ $labels.device }} on {{ $labels.instance }} has been experiencing errors for more than 15 minutes.";
                };
              }
              {
                alert = "SmokepingPacketLoss";
                expr = ''
                  (1 - rate(smokeping_response_duration_seconds_count[5m])
                  / rate(smokeping_requests_total[5m])) > 0.1
                '';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Packet loss >10% to {{ $labels.host }} from {{ $labels.instance }}";
                  description = "Smokeping is detecting sustained packet loss to {{ $labels.host }}.";
                };
              }
              {
                alert = "SmokepingTargetDown";
                expr = "rate(smokeping_response_duration_seconds_count[5m]) == 0 and rate(smokeping_requests_total[5m]) > 0";
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "100% packet loss to {{ $labels.host }} from {{ $labels.instance }}";
                  description = "Smokeping is detecting complete packet loss to {{ $labels.host }} for more than 15 minutes.";
                };
              }
            ];
          }

          # Application-level alerts
          {
            name = "application";
            rules = [
              # Metric names verified against the pinned litestream 0.5.11
              # source (db.go, internal/internal.go). The replica_operation
              # counters cover the S3/garage path (expired creds, unreachable
              # endpoint); sync counters cover the local WAL sync.
              {
                alert = "LitestreamReplicaOpErrors";
                expr = "increase(litestream_replica_operation_errors_total[15m]) > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Litestream replica operations failing on {{ $labels.instance }}";
                  description = "Litestream S3 replica operations have been failing for 15 minutes. Check garage reachability and the credentials in secrets/litestream-oracldn.age.";
                };
              }
              {
                alert = "LitestreamSyncErrors";
                expr = "increase(litestream_sync_error_count[15m]) > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Litestream local sync failing for {{ $labels.db }}";
                  description = "Litestream cannot sync the local database {{ $labels.db }}; replication is stalled.";
                };
              }
              {
                alert = "LitestreamVerifyErrors";
                expr = "increase(litestream_compaction_verify_error_count[6h]) > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Litestream compaction verification failed on {{ $labels.instance }}";
                  description = "Litestream compaction verification errors indicate the replica may not be restorable.";
                };
              }
              {
                alert = "LitestreamMetricsMissing";
                # Canary against metric renames: a future litestream bump that
                # renames its metrics must page, not silently go green.
                expr = ''absent(litestream_sync_count) and on() up{job="litestream"} == 1'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "Litestream exporter is up but litestream_sync_count is absent";
                  description = "The litestream metric names have changed (version bump?). All litestream alerts are blind until the rules are updated.";
                };
              }
              {
                alert = "LitestreamRestoreStale";
                # litestream-restore-test stamps this on a clean weekly restore
                # + integrity check (textfile collector). >2 weeks means the
                # test has been failing or the timer stopped — a replica we
                # can no longer prove is restorable.
                expr = ''time() - litestream_restore_test_last_success_seconds > 14 * 86400'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "Litestream has not passed a restore test in over two weeks";
                  description = "The weekly restore + integrity check has not succeeded recently; the sqlite replicas may not be restorable. Check litestream-restore-test.service.";
                };
              }
              # Syncthing folder states verified against pinned 2.0.15 source:
              # 0=idle … 8=error (lib/model/folderstate.go).
              {
                alert = "SyncthingFolderError";
                expr = ''syncthing_model_folder_state == 8'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "Syncthing folder {{ $labels.folder }} on {{ $labels.host }} is in error state";
                  description = "The folder has stopped syncing; restic is snapshotting stale data until this is fixed.";
                };
              }
              {
                alert = "SyncthingFolderStuck";
                expr = ''min_over_time(syncthing_model_folder_state[6h]) > 0'';
                labels.severity = "warning";
                annotations = {
                  summary = "Syncthing folder {{ $labels.folder }} on {{ $labels.host }} not idle for 6h";
                  description = "The folder has been scanning/syncing continuously for 6 hours — likely wedged.";
                };
              }
              {
                alert = "SyncthingFolderConflicts";
                expr = ''increase(syncthing_model_folder_conflicts_total[1h]) > 0'';
                labels.severity = "warning";
                annotations = {
                  summary = "New syncthing conflicts in {{ $labels.folder }} on {{ $labels.host }}";
                  description = "Conflicting edits are being shelved as .sync-conflict files; someone should reconcile them.";
                };
              }
              {
                alert = "SyncthingNoConnections";
                expr = ''sum by (host, instance) (syncthing_connections_active) == 0'';
                for = "12h";
                labels.severity = "warning";
                annotations = {
                  summary = "Syncthing {{ $labels.instance }} has had no connected peers for 12h";
                  description = "Nothing is syncing with this instance. Laptop peers sleep — hence the long fuse — but half a day of isolation on a server instance is real.";
                };
              }
              {
                alert = "GarageUnhealthy";
                expr = "cluster_healthy == 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Garage on {{ $labels.host }} reports unhealthy";
                  description = "Garage is the litestream replica target — sqlite replication is failing while this is down.";
                };
              }
              {
                alert = "PostgreSQLDown";
                expr = "pg_up == 0";
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "PostgreSQL is down on {{ $labels.instance }}";
                  description = "The PostgreSQL database on {{ $labels.instance }} is unreachable.";
                };
              }
              {
                alert = "PostgreSQLHighConnections";
                expr = "pg_stat_activity_count > 80";
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "PostgreSQL connections high on {{ $labels.instance }}: {{ $value }}";
                  description = "PostgreSQL on {{ $labels.instance }} has more than 80 active connections (default max is 100).";
                };
              }
              {
                alert = "OracleCostNonZero";
                expr = "oci_usage_month_total > 0";
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "Oracle account {{ $labels.account }} has spent {{ $value }} this month";
                  description = "Oracle Cloud account {{ $labels.account }} reports nonzero cost this month; something has left the Always Free tier.";
                };
              }
              {
                alert = "OracleUsageStale";
                # Covers both failing queries and a wedged poller; the
                # exporter refreshes hourly on success.
                expr = "time() - oci_usage_last_success_seconds > 3 * 3600";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Oracle usage data for {{ $labels.account }} is stale";
                  description = "The OCI usage exporter has not had a successful usage query for account {{ $labels.account }} in over 3 hours.";
                };
              }
              {
                alert = "OracleUsageMetricsMissing";
                # Canary: exporter up but emitting no usage series (renamed
                # metric, broken OCI query at startup). Without
                # oci_usage_month_total the critical OracleCostNonZero can
                # never fire, so a cost overrun would pass silently — and a
                # time()-based staleness check cannot fire on an absent series.
                expr = ''absent(oci_usage_month_total) and on () up{job="oci-usage"} == 1'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "OCI usage exporter is up but emitting no usage metrics";
                  description = "oci_usage_month_total is absent while the oci-usage scrape is up; the Oracle cost and staleness alerts are both blind.";
                };
              }
              {
                alert = "ResticBackupStale";
                expr = ''time() - systemd_timer_last_trigger_seconds{name=~"restic-backups-.*\\.timer",name!~"restic-backups-jotta\\.timer"} > 2 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "Restic backup {{ $labels.name }} stale on {{ $labels.instance }}";
                  description = "The restic backup timer {{ $labels.name }} on {{ $labels.instance }} has not triggered in over 2 hours (expected: hourly).";
                };
              }
              {
                alert = "SensorPipelineSilent";
                # Catches the whole class of "exporter up, broker empty" breaks
                # (wrong broker, z2m dead, zigbee radio wedged).
                expr = ''sum(increase(sensor_message_total[1h])) == 0 or absent(sensor_message_total)'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "No zigbee sensor messages for over an hour";
                  description = "mqtt-exporter on home-ldn is not seeing any messages; zigbee2mqtt, its broker, or the exporter subscription is broken.";
                };
              }
              {
                alert = "SensorBatteryLow";
                expr = ''min by (sensor) (sensor_battery) < 15'';
                for = "6h";
                labels.severity = "warning";
                annotations = {
                  summary = "Zigbee sensor {{ $labels.sensor }} battery at {{ $value }}%";
                  description = "Replace the battery before the sensor goes dark.";
                };
              }
              {
                alert = "ResticBackupStaleJotta";
                expr = ''time() - systemd_timer_last_trigger_seconds{name=~"restic-backups-jotta\\.timer"} > 4 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "Restic Jottacloud backup {{ $labels.name }} stale on {{ $labels.instance }}";
                  description = "The Jottacloud restic backup timer {{ $labels.name }} on {{ $labels.instance }} has not triggered in over 4 hours (expected: hourly, but rclone uploads can be slow).";
                };
              }
              # Backup TRUTH: the timer alerts above only prove the timer
              # fired. restic-jobs.nix pushes a success timestamp after every
              # completed run; a backup that runs-and-fails hourly goes stale
              # here while the timer alert stays green.
              {
                alert = "ResticBackupNotSucceeding";
                expr = ''time() - restic_backup_last_success_timestamp_seconds{repo!="jotta"} > 3 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "Restic {{ $labels.repo }} on {{ $labels.instance }}: no successful backup for 3h";
                  description = "The backup unit is firing but not completing successfully (hourly schedule expected). Check the unit log; ServiceFailed may have details.";
                };
              }
              {
                alert = "ResticBackupNotSucceedingJotta";
                expr = ''time() - restic_backup_last_success_timestamp_seconds{repo="jotta"} > 8 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "Restic jotta on {{ $labels.instance }}: no successful offsite backup for 8h";
                  description = "The Jottacloud job is the only offsite copy of /storage; slow rclone uploads get 8h of slack, silence beyond that is real.";
                };
              }
              {
                alert = "ResticRepoNoNewSnapshots";
                # Repo-side cross-check on the REST servers: snapshot blobs
                # written per repo. Counter resets on restart, hence increase()
                # guarded by the exporter being up; secondary to the client
                # push above.
                expr = ''sum by (repo) (increase(rest_server_blob_write_bytes_total{type="snapshots"}[26h])) == 0 and on () up{job="restic-server"} == 1'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "No new snapshots written to repo {{ $labels.repo }} in 26h";
                  description = "No client has completed a backup into this repository for over a day.";
                };
              }
              # Jotta proxy (rclone serve restic on core.tjoda): the whole
              # fleet's offsite path. Warning tier — the per-client
              # ResticBackupNotSucceedingJotta criticals are the backstop.
              {
                alert = "ResticJottaProxyDown";
                expr = ''probe_success{job="restic-jotta-probe"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Jotta restic proxy is not answering on its VIP";
                  description = "restic-jotta.dalby.ts.net is unreachable: rclone-jotta.service on core.tjoda is down, the VIP advertisement broke, or the grant changed. Every host's offsite backup fails until this is back.";
                };
              }
              {
                alert = "ResticJottaProxyNoTraffic";
                # Repo-side cross-check, the rest_server_blob_write equivalent
                # for the proxy: rclone only has core transfer stats, but
                # hourly client backups mean bytes must flow daily. Counter
                # resets on restart, hence increase() guarded by up.
                expr = ''sum(increase(rclone_bytes_transferred_total{job="rclone-jotta"}[26h])) == 0 and on () up{job="rclone-jotta"} == 1'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "No bytes moved through the Jotta restic proxy in 26h";
                  description = "The proxy is up but no client backup has pushed data through it for over a day; check the client jotta jobs and the token-check unit on core.tjoda.";
                };
              }
              {
                alert = "ResticJottaProxyMetricsMissing";
                # Metric-rename canary: without it a renamed series turns the
                # no-traffic cross-check silently green.
                expr = ''absent(rclone_bytes_transferred_total) and on () up{job="rclone-jotta"} == 1'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Jotta proxy scrape is up but rclone_bytes_transferred_total is absent";
                  description = "The rclone metric names have changed (version bump?); ResticJottaProxyNoTraffic is blind until the rules are updated.";
                };
              }
              {
                alert = "PostgresqlBackupStale";
                expr = ''time() - systemd_timer_last_trigger_seconds{name=~"postgresqlBackup-.*\\.timer"} > 26 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "postgres dump {{ $labels.name }} stale on {{ $labels.host }}";
                  description = "The nightly pg_dump timer has not fired for over a day; the restic snapshots are carrying a stale dump.";
                };
              }
              {
                alert = "RusticBackupStale";
                # macOS laptops (krair/kratail2) back up irreplaceable data
                # (iMessage, Signal, Keychains) via rustic; the watchdog pushes
                # the newest-snapshot timestamp to the pushgateway. This is the
                # consumer: a laptop online but silently not backing up ages the
                # timestamp even while push_time stays fresh. 3 days tolerates
                # travel; the pushed value persists in the pushgateway so an
                # offline laptop still trips this rather than PushgatewayGroupStale.
                expr = ''time() - rustic_backup_last_snapshot_timestamp_seconds > 3 * 86400'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "rustic backup on {{ $labels.host }} is stale (>3d)";
                  description = "No fresh rustic snapshot for over three days; the laptop's backups have silently stopped.";
                };
              }
              {
                alert = "RusticBackupMetricsMissing";
                # Canary against the metric name being wrong or the pushgateway
                # being wiped — the RusticBackupStale threshold can never fire if
                # the series does not exist at all.
                expr = ''absent(rustic_backup_last_snapshot_timestamp_seconds)'';
                for = "6h";
                labels.severity = "warning";
                annotations = {
                  summary = "No rustic backup timestamp is being pushed by any laptop";
                  description = "rustic_backup_last_snapshot_timestamp_seconds is absent fleet-wide; the macOS backup dead-man is blind.";
                };
              }
              {
                alert = "SfiberProxyDown";
                # sfiber-check on core.tjoda pushes sfiber_proxy_up{proxy}=0 for a
                # tailscale-proxy that is not Running (expired key / dead foreign
                # headscale). The 0 is the whole signal — a down-but-still-pushing
                # proxy never trips PushgatewayGroupStale.
                expr = ''sfiber_proxy_up == 0'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "sfiber proxy {{ $labels.proxy }} is down";
                  description = "A remote-client backup-ingest tailscale proxy is not Running; remote backups into it fail silently.";
                };
              }
              {
                alert = "NginxLogParseErrors";
                # The only signal that a log-format change silently zeroed the
                # nginxlog counters — which would make the nginx availability SLO
                # read 100% healthy against no data.
                expr = ''rate(nginxlog_parse_errors_total[10m]) > 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "nginxlog exporter failing to parse the access log on {{ $labels.host }}";
                  description = "Parse errors mean the log format drifted; nginxlog_http_response_count_total is silently undercounting and the nginx SLO is blind.";
                };
              }
              {
                alert = "Ts1pOpAuthFailed";
                # A revoked/expired 1Password service-account credential —
                # otherwise hidden behind the 24h secret cache until it drains.
                # ts1p_op_auth_failed_total is a varz counter (source-verified);
                # requires the ts1p /metrics fork + tcp:443 ACL to setec.
                expr = ''increase(ts1p_op_auth_failed_total[30m]) > 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "ts1p (setec) 1Password authentication is failing";
                  description = "The fleet secrets server cannot authenticate to 1Password; secret warms will fail once the cache drains.";
                };
              }
            ];
          }

          # Headscale — the tailnet control plane. Alerts use only NATIVE,
          # namespaced headscale_* metrics (verified in hscontrol/metrics.go):
          # mapresponse errors, nodestore, queue depth, resource use. We
          # deliberately do NOT touch go-chi's http_requests_total — it is
          # OPTIONS-only upstream (Skip bug) and adds nothing over these.
          {
            name = "headscale";
            rules = [
              {
                alert = "HeadscaleNodestoreEmpty";
                # The fingerprint of a bad restore / wiped sqlite: process up,
                # zero nodes.
                expr = ''headscale_nodestore_nodes == 0'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "Headscale reports zero nodes";
                  description = "The node table is empty while headscale runs — wiped or corrupt database, or a bad litestream restore.";
                };
              }
              {
                alert = "HeadscaleMapResponseErrors";
                expr = ''sum(rate(headscale_mapresponse_sent_total{status="error"}[10m])) > 0'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "Headscale is failing to send map responses";
                  description = "Clients are not receiving netmap updates; the tailnet is degrading.";
                };
              }
              {
                alert = "HeadscaleQueueBacklog";
                # sqlite write-contention proxy.
                expr = ''headscale_nodestore_queue_depth > 10'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Headscale nodestore queue depth {{ $value }}";
                  description = "Write operations are queueing — sqlite contention or an overloaded event loop.";
                };
              }
              {
                alert = "HeadscaleResourceExhaustion";
                # fd ratio is the earliest overload signal: every long-poll
                # holds a descriptor. CPU/goroutine bounds tuned vs. an idle
                # baseline of a small homelab tailnet.
                expr = ''
                  process_open_fds{job="headscale"} / process_max_fds{job="headscale"} > 0.8
                                    or rate(process_cpu_seconds_total{job="headscale"}[5m]) > 0.8
                                    or go_goroutines{job="headscale"} > 1000
                                    or process_resident_memory_bytes{job="headscale"} > 1e9
                '';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Headscale resource pressure on {{ $labels.instance }}";
                  description = "File descriptors, CPU, goroutines, or RSS are far above baseline — headscale is overloaded or leaking.";
                };
              }
            ];
          }

          # Saturation / oversubscription — the "everything is slow but
          # nothing is down" tier for the small shared Oracle VMs. PSI is the
          # load-bearing signal; steal stays ~0 on A1 Flex (dedicated OCPUs),
          # so no steal alert.
          {
            name = "saturation";
            rules = [
              {
                alert = "CPUPressure";
                expr = ''rate(node_pressure_cpu_waiting_seconds_total[10m]) > 0.25'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: tasks waiting for CPU {{ $value | humanizePercentage }} of the time";
                  description = "Sustained CPU pressure — the box is oversubscribed for its workload.";
                };
              }
              {
                alert = "MemoryPressure";
                expr = ''rate(node_pressure_memory_stalled_seconds_total[10m]) > 0.05'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.host }}: actively thrashing on memory";
                  description = "Tasks are fully stalled on memory reclaim; the host is effectively unusable until pressure drops.";
                };
              }
              {
                alert = "SwapThrash";
                expr = ''
                  rate(node_vmstat_pswpout[10m]) > 1000
                                    and (node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes > 0.8
                '';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: swapping heavily with swap nearly full";
                  description = "zram/swap is thrashing — memory is oversubscribed. Mere swap usage never alerts; sustained swap-out does.";
                };
              }
              {
                alert = "ConntrackNearLimit";
                # Ratio self-selects the NAT gateways; other hosts idle far
                # below the limit.
                expr = ''node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: conntrack table {{ $value | humanizePercentage }} full";
                  description = "The NAT gateway is about to start dropping new connections.";
                };
              }
              {
                alert = "FileDescriptorsNearLimit";
                expr = ''node_filefd_allocated / node_filefd_maximum > 0.8'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}: system file descriptors {{ $value | humanizePercentage }} of max";
                  description = "Something is leaking fds; services will start failing to open sockets/files.";
                };
              }
              {
                alert = "HttpsProbeSlow";
                # The 1–5s degraded band: the probe module times out at 5s
                # (down), but sustained slowness is the earliest user-visible
                # oversubscription signal.
                expr = ''probe_duration_seconds{job="https-probes"} > 2'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }} responding slowly ({{ $value }}s)";
                  description = "The endpoint answers but takes >2s — degraded, likely host saturation or upstream trouble.";
                };
              }
            ];
          }

          # Monitoring-of-the-monitoring. The Watchdog fires always; a
          # dedicated Alertmanager route forwards it to healthchecks.io, which
          # pages out-of-band when the pings stop. Everything else here would
          # otherwise fail silently into the same Discord webhook it reports on.
          {
            name = "monitoring";
            rules = [
              {
                alert = "Watchdog";
                expr = "vector(1)";
                labels.severity = "heartbeat";
                annotations = {
                  summary = "Dead-man heartbeat";
                  description = "Always firing. If healthchecks.io stops receiving this, Prometheus, Alertmanager, or the delivery path is down.";
                };
              }
              {
                alert = "PrometheusRuleEvalFailures";
                expr = "increase(prometheus_rule_evaluation_failures_total[15m]) > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Prometheus rule evaluation is failing";
                  description = "{{ $value }} rule evaluation failures in 15m — some alerts are not being evaluated at all.";
                };
              }
              {
                alert = "PrometheusNotificationErrors";
                expr = "increase(prometheus_notifications_errors_total[15m]) > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Prometheus cannot deliver alerts to Alertmanager";
                  description = "Errors on the Prometheus → Alertmanager leg; firing alerts may not be reaching any receiver.";
                };
              }
              {
                alert = "PrometheusTSDBErrors";
                expr = "increase(prometheus_tsdb_compactions_failed_total[4h]) > 0 or increase(prometheus_tsdb_wal_corruptions_total[4h]) > 0";
                labels.severity = "critical";
                annotations = {
                  summary = "Prometheus TSDB compaction/WAL errors on {{ $labels.instance }}";
                  description = "The metrics store itself is unhealthy; history and alerting are at risk.";
                };
              }
              {
                alert = "AlertmanagerConfigReloadFailed";
                expr = "alertmanager_config_last_reload_successful == 0";
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "Alertmanager is running a stale configuration";
                  description = "The last Alertmanager config reload failed; routing/receiver changes are not in effect.";
                };
              }
            ];
          }

          # Incus hypervisor and VM alerts
          {
            name = "incus";
            rules = [
              # Daemon health
              {
                alert = "IncusDaemonDown";
                expr = ''up{job="incus"} == 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Incus daemon unreachable on {{ $labels.instance }}";
                  description = "The Incus metrics endpoint on {{ $labels.instance }} has been down for more than 5 minutes. All VMs on this hypervisor may be affected.";
                };
              }
              {
                alert = "IncusDaemonWarnings";
                expr = "incus_warnings_total > 0";
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Incus daemon has {{ $value }} active warnings on {{ $labels.instance }}";
                  description = "The Incus daemon on {{ $labels.instance }} is reporting active warnings. Check 'incus warning list'.";
                };
              }
              {
                alert = "IncusDaemonRestarted";
                expr = "incus_uptime_seconds < 300";
                labels.severity = "warning";
                annotations = {
                  summary = "Incus daemon recently restarted on {{ $labels.instance }}";
                  description = "The Incus daemon on {{ $labels.instance }} has been running for less than 5 minutes (uptime: {{ $value }}s).";
                };
              }

              # Per-VM instance alerts
              {
                alert = "IncusVMVanished";
                # The Incus suite has no "instance stopped" rule; a VM that
                # stops (or is deleted) simply drops its series.
                expr = ''absent(incus_memory_MemTotal_bytes{name="ts1p"}) or absent(incus_memory_MemTotal_bytes{name="dev"}) or absent(incus_memory_MemTotal_bytes{name="home"}) or absent(incus_memory_MemTotal_bytes{name="storage"}) or absent(incus_memory_MemTotal_bytes{name="garnix"})'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  # absent() carries the name label from its equality matcher.
                  summary = "Incus VM {{ $labels.name }} has vanished from hypervisor metrics";
                  description = "The VM no longer reports from its hypervisor — stopped, deleted, or renamed.";
                };
              }
              {
                alert = "TsnixcacheDiskFull";
                # tsnixcache is the ONLY GC on gigabuilder's nix store (fleet
                # GC is force-disabled); if GC wedges, the build host fills up.
                expr = ''tsnixcache_gc_disk_used_pct > 97'';
                for = "1h";
                labels.severity = "critical";
                annotations = {
                  summary = "tsnixcache store disk {{ $value }}% full";
                  description = "GC is not keeping up (or is broken) on gigabuilder; builds will start failing when the store fills.";
                };
              }
              {
                alert = "TsnixcacheGCErrors";
                expr = ''increase(tsnixcache_gc_errors_total[1h]) > 0'';
                labels.severity = "warning";
                annotations = {
                  summary = "tsnixcache GC reporting errors";
                  description = "Garbage collection on the fleet nix cache is failing; disk-full follows if this persists.";
                };
              }
              {
                alert = "IncusInstanceOOMKill";
                expr = "increase(incus_memory_OOM_kills_total[5m]) > 0";
                for = "1m";
                labels.severity = "critical";
                annotations = {
                  summary = "OOM kill in Incus VM {{ $labels.name }}";
                  description = "An OOM kill was detected inside the Incus VM {{ $labels.name }} ({{ $labels.type }}).";
                };
              }
              {
                alert = "IncusInstanceMemoryPressure";
                expr = "(incus_memory_MemAvailable_bytes / incus_memory_MemTotal_bytes) < 0.10";
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Incus VM {{ $labels.name }} has less than 10% memory available";
                  description = "The Incus VM {{ $labels.name }} has {{ $value | humanizePercentage }} memory available. Consider increasing its memory allocation.";
                };
              }
              {
                alert = "IncusInstanceSwapHigh";
                expr = "incus_memory_Swap_bytes > 1e9";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Incus VM {{ $labels.name }} using {{ $value | humanize1024 }}B swap";
                  description = "The Incus VM {{ $labels.name }} is using more than 1GB of swap for over 15 minutes. This may indicate memory pressure.";
                };
              }
              {
                alert = "IncusInstanceNetworkErrors";
                expr = ''rate(incus_network_receive_errs_total{device!="lo"}[5m]) + rate(incus_network_transmit_errs_total{device!="lo"}[5m]) > 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Network errors on {{ $labels.device }} in Incus VM {{ $labels.name }}";
                  description = "The network interface {{ $labels.device }} in Incus VM {{ $labels.name }} has been experiencing errors.";
                };
              }

              # Hypervisor host alerts. IncusOS passes node_* series through
              # its /1.0/metrics endpoint (live-verified 2026-07: 4483 node_*
              # series incl. fstype="ext4",mountpoint="/"). Only the default
              # node_exporter collectors come through (cpu/meminfo/filesystem/
              # diskstats/loadavg/hwmon/netdev/nvme) — the systemd collector is
              # NOT among them, so there is no node_systemd_unit_state to alert
              # a failed hypervisor unit on. SMART is likewise absent —
              # smartmontools runs on IncusOS itself; the physical disks' SMART
              # is an accepted blind spot here.
              {
                alert = "HypervisorLowMem";
                expr = ''(node_memory_MemAvailable_bytes{role="incus"} / node_memory_MemTotal_bytes{role="incus"}) * 100 < 5'';
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "Hypervisor {{ $labels.instance }}: {{ $value }}% memory available";
                  description = "The Incus hypervisor has less than 5% memory available. All VMs on this host may be affected.";
                };
              }
              {
                alert = "HypervisorLowDisk";
                expr = ''node_filesystem_avail_bytes{role="incus",fstype="ext4",mountpoint="/"} / 1024 / 1024 < 2048'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Hypervisor {{ $labels.instance }}: {{ $value }}MB free on root filesystem";
                  description = "The Incus hypervisor root filesystem has less than 2GB free. This can prevent VM operations and daemon functionality.";
                };
              }
              {
                alert = "HypervisorHighCPU";
                expr = ''node_load15{role="incus"} > count without (cpu, mode) (node_cpu_seconds_total{role="incus",mode="idle"})'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Hypervisor {{ $labels.instance }}: 15m load average {{ $value }} exceeds CPU count";
                  description = "The Incus hypervisor load average has exceeded its CPU count for more than 15 minutes. VM performance may be degraded.";
                };
              }
            ];
          }
        ];
      })
    ];

    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = blackboxConfigFile;
    };

    alertmanager = {
      enable = true;

      listenAddress = "0.0.0.0";

      webExternalUrl = "http://alertmanager/";

      # environmentFile interpolation is done after the check config
      # is done, which means it will fail with a missing discord webhook.
      checkConfig = false;
      environmentFile = config.age.secrets.alertmanager-env.path;

      configuration = {
        route = {
          group_by = [
            "alertname"
            "host"
            "instance"
          ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
          receiver = "discord";
          routes = [
            {
              # Dead-man heartbeat: continuously re-notified to healthchecks.io,
              # never to Discord. Silence on this route is what pages.
              match = {severity = "heartbeat";};
              receiver = "deadman";
              group_wait = "10s";
              group_interval = "1m";
              repeat_interval = "4m";
            }
            {
              match = {severity = "critical";};
              receiver = "critical";
              group_wait = "10s";
              group_interval = "1m";
              repeat_interval = "1h";
            }
            {
              match = {severity = "warning";};
              receiver = "discord";
              group_wait = "2m";
              group_interval = "10m";
              repeat_interval = "12h";
            }
          ];
        };

        # Inhibits match on the port-free "host" label; "instance" carries the
        # exporter port (core-tjoda:9100 vs :9558) and never matched across
        # jobs, so a dead host used to flood one alert per exporter.
        inhibit_rules = [
          {
            # If a node is down, suppress all other alerts from that host
            source_matchers = ["alertname=\"NodeExporterDown\""];
            target_matchers = ["alertname!=\"NodeExporterDown\""];
            equal = ["host"];
          }
          {
            # If an exporter is down, suppress downstream alerts from that host
            source_matchers = ["alertname=\"ExporterDown\""];
            target_matchers = ["alertname!~\"ExporterDown|NodeExporterDown\""];
            equal = ["host" "job"];
          }
          {
            # Critical inhibits warning for the same alert+host
            source_matchers = ["severity=\"critical\""];
            target_matchers = ["severity=\"warning\""];
            equal = ["alertname" "host"];
          }
          {
            # A resolver being unreachable (DnsProbeDown) makes every ICMP probe
            # for names in that site fail too — they can't resolve. Suppress the
            # per-device flood (e.g. 13× TjodaPingDown) and page once on the
            # resolver. Matches on the shared "site" label set on both jobs.
            source_matchers = ["alertname=\"DnsProbeDown\""];
            target_matchers = ["alertname=\"TjodaPingDown\""];
            equal = ["site"];
          }
        ];

        receivers = [
          {
            name = "discord";
            discord_configs = [
              {
                webhook_url = "$DISCORD_WEBHOOK_URL";
              }
            ];
          }
          {
            # Critical fans out to Discord AND email so a dead webhook alone
            # can't hide a page. Email relays through gigabuilder (smtp.fap.no).
            name = "critical";
            discord_configs = [
              {
                webhook_url = "$DISCORD_WEBHOOK_URL";
              }
            ];
            email_configs = [
              {
                to = "kristoffer@dalby.cc";
                from = "alertmanager@oracldn.fap.no";
                # core.oracldn no longer runs a local postfix (it uses send-only
                # nullmailer). Relay email through gigabuilder's SMTP relay, same
                # as the rest of the fleet.
                smarthost = "smtp.fap.no:25";
                require_tls = false;
              }
            ];
          }
          {
            # healthchecks.io ping URL; pinged on every Watchdog re-notify.
            # HEALTHCHECKS_WATCHDOG_URL must exist in secrets/alertmanager-env.age.
            name = "deadman";
            webhook_configs = [
              {
                url = "$HEALTHCHECKS_WATCHDOG_URL";
                send_resolved = false;
              }
            ];
          }
        ];
      };
    };

    pushgateway = {
      enable = true;

      web = {
        external-url = "https://pushgateway.oracldn.fap.no";
        listen-address = "localhost:9091";
      };

      persistMetrics = true;
    };
  };

  # The NixOS module sets an empty CapabilityBoundingSet which blocks the
  # AmbientCapabilities=CAP_NET_RAW needed for ICMP probes.
  systemd.services.prometheus-blackbox-exporter.serviceConfig = {
    CapabilityBoundingSet = ["CAP_NET_RAW"];
  };
}
