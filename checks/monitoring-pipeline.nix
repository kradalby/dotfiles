{
  pkgs,
  self,
  ...
}:
# End-to-end alert pipeline against the REAL core.oracldn Alertmanager route:
# one always-firing rule per severity must reach the receiver the *production*
# route assigns it to. The real receivers point at Discord / healthchecks /
# email (secrets + URLs that can't run in a VM), so they are stubbed to a local
# webhook; the route tree — matchers, receiver names, the heartbeat→deadman
# leg — is the real thing. This catches routing/receiver regressions that
# checkConfig=false and the rule unit tests cannot see. Only the timers are
# shortened so the dead-man's re-notify is observable within the test window.
let
  prodRoute =
    self.nixosConfigurations.core-oracldn.config.services.prometheus.alertmanager.configuration.route;
  fastRoute = prodRoute // {
    group_wait = "1s";
    group_interval = "2s";
    repeat_interval = "5s";
    routes = map (
      r:
      r
      // {
        group_wait = "1s";
        repeat_interval = "5s";
      }
    ) prodRoute.routes;
  };
in
pkgs.testers.runNixOSTest {
  name = "monitoring-pipeline";

  nodes.machine = { pkgs, ... }: {
    services.prometheus = {
      enable = true;
      globalConfig.evaluation_interval = "2s";

      rules = [
        (builtins.toJSON {
          groups = [
            {
              name = "test";
              rules = [
                {
                  alert = "Watchdog";
                  expr = "vector(1)";
                  labels.severity = "heartbeat";
                }
                {
                  alert = "AlwaysCritical";
                  expr = "vector(1)";
                  labels.severity = "critical";
                }
                {
                  alert = "AlwaysWarning";
                  expr = "vector(1)";
                  labels.severity = "warning";
                }
              ];
            }
          ];
        })
      ];

      alertmanagers = [
        {
          scheme = "http";
          static_configs = [ { targets = [ "localhost:9093" ]; } ];
        }
      ];

      alertmanager = {
        enable = true;
        listenAddress = "127.0.0.1";
        configuration = {
          route = fastRoute;
          # Stub the three production receivers to a local webhook. Names MUST
          # match what the real route references (discord / critical / deadman)
          # — a rename in the route with no matching receiver fails the test.
          receivers = [
            {
              name = "discord";
              webhook_configs = [ { url = "http://127.0.0.1:8081/discord"; } ];
            }
            {
              name = "critical";
              webhook_configs = [ { url = "http://127.0.0.1:8081/critical"; } ];
            }
            {
              name = "deadman";
              webhook_configs = [
                {
                  url = "http://127.0.0.1:8081/deadman";
                  send_resolved = false;
                }
              ];
            }
          ];
        };
      };
    };

    # Tiny webhook stub recording which receiver delivered.
    systemd.services.webhook-stub = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = pkgs.writers.writePython3 "webhook-stub" { } ''
        import http.server


        class H(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                self.rfile.read(int(self.headers.get("Content-Length", 0)))
                with open("/tmp/hits", "a") as f:
                    f.write(self.path + "\n")
                self.send_response(200)
                self.end_headers()


        http.server.HTTPServer(("127.0.0.1", 8081), H).serve_forever()
      '';
    };
  };

  testScript = ''
    machine.wait_for_unit("prometheus.service")
    machine.wait_for_unit("alertmanager.service")
    machine.wait_for_unit("webhook-stub.service")
    machine.wait_for_open_port(9090)
    machine.wait_for_open_port(9093)

    # Each severity must land at the receiver the PRODUCTION route assigns:
    # heartbeat→deadman, critical→critical, warning→discord.
    machine.wait_until_succeeds("grep -q /deadman /tmp/hits", timeout=120)
    machine.wait_until_succeeds("grep -q /critical /tmp/hits", timeout=120)
    machine.wait_until_succeeds("grep -q /discord /tmp/hits", timeout=120)

    # The heartbeat route must keep re-notifying (dead-man semantics).
    machine.succeed("cp /tmp/hits /tmp/hits.snapshot")
    machine.wait_until_succeeds(
        "[ $(grep -c /deadman /tmp/hits) -gt $(grep -c /deadman /tmp/hits.snapshot) ]",
        timeout=120,
    )
  '';
}
