{
  pkgs,
  self,
  ...
}:
# Umami as core.oracldn runs it: the production settings and the production
# umami-sites unit, on an empty database. Proves that the websites in
# metadata/umami.nix get created against the schema of the pinned Umami and
# that the server then accepts a pageview for each of them. A website ID that
# does not exist makes Umami drop the beacon, so a schema change that broke the
# insert would otherwise only show up as empty statistics.
let
  prod = self.nixosConfigurations.core-oracldn.config;
  sites = import ../metadata/umami.nix;
  port = toString prod.services.umami.settings.PORT;
in
pkgs.testers.runNixOSTest {
  name = "umami";

  nodes.machine =
    { pkgs, lib, ... }:
    {
      imports = [ ../machines/core.oracldn/umami-sites.nix ];

      virtualisation.memorySize = 2048;

      # By name, not by store path: production is another architecture.
      services.postgresql.package =
        pkgs."postgresql_${lib.versions.major prod.services.postgresql.package.version}";

      services.umami = {
        enable = true;
        settings = prod.services.umami.settings // {
          APP_SECRET_FILE = "${pkgs.writeText "umami-app-secret" "vm-test"}";
        };
      };
    };

  testScript = ''
    import json

    sites = json.loads('${builtins.toJSON sites}')

    def send(site_id, domain):
        payload = json.dumps({"type": "event", "payload": {
            "website": site_id, "hostname": domain, "url": "/", "language": "en-US", "screen": "1920x1080",
        }})
        return machine.execute(
            "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${port}/api/send "
            "-H 'Content-Type: application/json' "
            "-A 'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0' "
            f"-d '{payload}'"
        )[1]

    def events(site_id):
        return machine.succeed(
            f"sudo -u postgres psql -At umami -c \"SELECT count(*) FROM website_event WHERE website_id = '{site_id}'\""
        ).strip()

    machine.wait_for_unit("umami.service")
    machine.wait_for_open_port(${port})
    machine.wait_until_succeeds(
        f"sudo -u postgres psql -At umami -c 'SELECT count(*) FROM website' | grep -x {len(sites)}"
    )

    for name, site in sites.items():
        with subtest(f"{name} records a pageview"):
            code = send(site["id"], site["domain"])
            assert code == "200", f"{name}: /api/send returned {code}"
            assert events(site["id"]) == "1", f"{name}: no event stored"

    with subtest("an unknown website is refused"):
        unknown = "00000000-0000-4000-8000-000000000000"
        code = send(unknown, "example.com")
        assert code != "200", f"unknown website accepted: {code}"
        assert events(unknown) == "0"
  '';
}
