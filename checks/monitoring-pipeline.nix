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
  prodRules = builtins.fromJSON (
    builtins.head self.nixosConfigurations.core-oracldn.config.services.prometheus.rules
  );
  vanishedRules = builtins.filter (r: (r.alert or "") == "IncusVMVanished") (
    pkgs.lib.concatMap (g: g.rules) prodRules.groups
  );
  fastRoute = prodRoute // {
    group_wait = "1s";
    group_interval = "2s";
    repeat_interval = "5s";
    routes = map (
      r:
      r
      // {
        group_wait = "1s";
        group_interval = "2s";
        repeat_interval = "5s";
      }
    ) prodRoute.routes;
  };
in
pkgs.testers.runNixOSTest {
  name = "monitoring-pipeline";

  nodes.machine = { pkgs, lib, ... }: {
    # Start Prometheus only after the sinks are ready: otherwise its initial
    # source-alert batch can fail, while later guest alerts arrive first.
    systemd.services.prometheus.wantedBy = lib.mkForce [ ];
    services.prometheus = {
      enable = true;
      globalConfig.evaluation_interval = "2s";

      rules = [
        (builtins.toJSON {
          groups = [
            {
              name = "test";
              # Run the exact production missing-guest expressions with only
              # their hold time shortened. No Incus metrics exist in this VM.
              # As in production (guest 10m, daemon 5m), the source fires
              # before the guests, giving Alertmanager time to inhibit them.
              rules = map (r: r // { for = "10s"; }) vanishedRules ++ [
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
                {
                  alert = "IncusDaemonDown";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    job = "incus";
                    instance = "core-ldn:8443";
                    host = "core-ldn";
                    target = "core-ldn";
                    hypervisor = "core-ldn";
                  };
                }
                {
                  alert = "AlertmanagerDeliveryErrorBudgetBurn";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    integration = "discord";
                  };
                }
                {
                  alert = "AlertmanagerDeliveryErrorBudgetBurn";
                  expr = "vector(1)";
                  labels = {
                    severity = "warning";
                    integration = "discord";
                  };
                }
                {
                  alert = "AlertmanagerDeliveryErrorBudgetBurn";
                  expr = "vector(1)";
                  labels = {
                    severity = "warning";
                    integration = "email";
                  };
                }
                {
                  alert = "SeverityInhibitionTest";
                  expr = "vector(1)";
                  labels = {
                    severity = "critical";
                    host = "severity-test-host";
                  };
                }
                {
                  alert = "SeverityInhibitionTest";
                  expr = "vector(1)";
                  labels = {
                    severity = "warning";
                    host = "severity-test-host";
                  };
                }
                {
                  alert = "SeverityInhibitionTest";
                  expr = "vector(1)";
                  labels = {
                    severity = "warning";
                    host = "other-severity-host";
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
                alerts = json.loads(body)["alerts"]
                with open("/tmp/hits", "a") as f:
                    f.write(json.dumps({"path": self.path, "alerts": alerts}) + "\n")
                self.send_response(200)
                self.end_headers()


        http.server.HTTPServer(("127.0.0.1", 8081), H).serve_forever()
      '';
    };
  };

  testScript = ''
    import json

    machine.wait_for_unit("alertmanager.service")
    machine.wait_for_unit("webhook-stub.service")
    machine.wait_for_open_port(9093)
    machine.wait_for_open_port(8081)
    machine.succeed("systemctl start prometheus.service")
    machine.wait_for_unit("prometheus.service")
    machine.wait_for_open_port(9090)

    # Each severity must land at the receiver the PRODUCTION route assigns:
    # heartbeat→deadman, critical→critical, warning→discord.
    expected = {
        "Watchdog": "/deadman",
        "AlwaysCritical": "/critical",
        "AlwaysWarning": "/discord",
        "NodeExporterDown": "/critical",
        "IndependentAlert": "/critical",
        "IncusDaemonDown": "/critical",
        "IncusVMVanished": "/critical",
    }
    for name in expected:
        machine.wait_until_succeeds(
            f"grep -q '\"alertname\": \"{name}\"' /tmp/hits", timeout=120
        )
    hits = [json.loads(line) for line in machine.succeed("cat /tmp/hits").splitlines()]
    received = {
        (a["labels"]["alertname"], hit["path"])
        for hit in hits
        for a in hit["alerts"]
        if a["labels"]["alertname"] in expected
    }
    # Seeing all three paths alone also passes if critical/warning routes are
    # swapped. Every alert must reach its expected receiver exclusively.
    assert received == set(expected.items()), received

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

    # A missing guest on the failed hypervisor must be inhibited, while the
    # identically named alert for the other hypervisor must still be delivered.
    # Inspect individual alerts inside grouped notifications, not just paths.
    machine.wait_until_succeeds("grep -q garnix /tmp/hits", timeout=120)
    hits = [json.loads(line) for line in machine.succeed("cat /tmp/hits").splitlines()]
    guests = [
        a["labels"]
        for hit in hits
        for a in hit["alerts"]
        if a["labels"]["alertname"] == "IncusVMVanished"
    ]
    assert guests and all(
        a["name"] == "garnix" and a["hypervisor"] == "gigabuilder" for a in guests
    ), guests
    assert any(
        a["labels"]["alertname"] == "IncusDaemonDown"
        for hit in hits
        for a in hit["alerts"]
    ), hits

    # A critical delivery failure must suppress only its integration's warning.
    # These alerts deliberately lack host, matching the generated Sloth labels.
    machine.wait_until_succeeds('grep -q "email" /tmp/hits', timeout=120)
    machine.wait_until_succeeds('grep -q "other-severity-host" /tmp/hits', timeout=120)
    hits = [json.loads(line) for line in machine.succeed("cat /tmp/hits").splitlines()]
    delivery = {
        (a["labels"]["integration"], a["labels"]["severity"], hit["path"])
        for hit in hits
        for a in hit["alerts"]
        if a["labels"]["alertname"] == "AlertmanagerDeliveryErrorBudgetBurn"
    }
    assert delivery == {
        ("discord", "critical", "/critical"),
        ("email", "warning", "/discord"),
    }, delivery

    # Without integration on either alert, same-host severity inhibition still
    # applies, while the warning from another host must be delivered.
    severity = {
        (a["labels"]["host"], a["labels"]["severity"], hit["path"])
        for hit in hits
        for a in hit["alerts"]
        if a["labels"]["alertname"] == "SeverityInhibitionTest"
    }
    assert severity == {
        ("severity-test-host", "critical", "/critical"),
        ("other-severity-host", "warning", "/discord"),
    }, severity
  '';
}
