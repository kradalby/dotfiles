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
  prodAm =
    self.nixosConfigurations.core-oracldn.config.services.prometheus.alertmanager.configuration;
  prodRoute = prodAm.route;
  prodInhibits = prodAm.inhibit_rules;
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
                # Inhibition trio: NodeExporterDown{target=X} must suppress a
                # dependent alert sharing target=X, but NOT one with target=Y.
                {
                  alert = "NodeExporterDown";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    target = "inhibit-test-host";
                  };
                }
                {
                  alert = "DependentAlert";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    target = "inhibit-test-host";
                  };
                }
                {
                  alert = "IndependentAlert";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    target = "other-test-host";
                  };
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
          # The REAL production inhibit rules — so this test also guards that a
          # dead host's dependents are suppressed while independents still fire.
          inhibit_rules = prodInhibits;
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
        import json


        class H(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                try:
                    names = ",".join(
                        a["labels"]["alertname"]
                        for a in json.loads(body).get("alerts", [])
                    )
                except Exception:
                    names = ""
                with open("/tmp/hits", "a") as f:
                    f.write(self.path + " " + names + "\n")
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

    # Inhibition: NodeExporterDown{target=inhibit-test-host} must suppress
    # DependentAlert (same target) but NOT IndependentAlert (other target).
    # Wait for the independent + source to arrive (pipeline settled), then
    # assert the dependent was never delivered — the suppression held.
    machine.wait_until_succeeds("grep -q IndependentAlert /tmp/hits", timeout=120)
    machine.succeed("grep -q NodeExporterDown /tmp/hits")
    machine.fail("grep -q DependentAlert /tmp/hits")
  '';
}
