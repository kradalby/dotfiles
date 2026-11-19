{
  pkgs,
  lib,
  config,
  ...
}:
let
  sites = import ../../metadata/umami.nix;

  # The website row belongs to the first admin so it shows up on their
  # dashboard; rows that already exist are left alone.
  ensureSites = pkgs.writeText "umami-sites.sql" ''
    INSERT INTO website (website_id, name, domain, user_id, created_by)
    SELECT v.id::uuid, v.domain, v.domain, u.user_id, u.user_id
    FROM (VALUES
      ${lib.concatMapStringsSep ",\n  " (s: "('${s.id}', '${s.domain}')") (lib.attrValues sites)}
    ) AS v(id, domain),
    (SELECT user_id FROM "user" WHERE role = 'admin' ORDER BY created_at LIMIT 1) AS u
    ON CONFLICT (website_id) DO NOTHING;
  '';
in
{
  # Kept apart from umami.nix so checks/umami.nix can run this exact unit.
  systemd.services.umami-sites = {
    description = "Ensure the Umami websites in metadata/umami.nix exist";
    wantedBy = [ "multi-user.target" ];
    after = [
      "umami.service"
      "postgresql.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      ExecStart = "${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -f ${ensureSites} umami";
      # On an empty database the tables exist only once umami has run its
      # migrations, which it does after systemd counts it as started.
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
