# Continuous replication of the atuin SQLite DB to tjoda's garage over the
# tailnet. Needs a litestream-oracfurt garage bucket + key (infra tofu root)
# and secrets/litestream-oracfurt.age. The module ships a weekly restore-test.
{...}: {
  imports = [
    ../../common/litestream.nix
  ];

  my.litestream.databases = [
    {
      name = "atuin.db";
      path = "/var/lib/atuin/atuin.db";
    }
  ];

  # litestream reads the db + writes its shadow dir inside /var/lib/atuin, so it
  # must be in the atuin group (dir is 0770, db 0640 — see atuin.nix).
  users.users.litestream.extraGroups = ["atuin"];
}
