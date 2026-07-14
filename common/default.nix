# Backwards-compatible shim: machines still importing `../../common` get the
# base + server profiles, i.e. the previous behaviour minus fail2ban (deleted
# everywhere) and avahi (now opt-in per machine). Migrate machines to import
# `./base.nix` (+ `../profiles/server.nix`) directly; this keeps the un-migrated
# ones working in the meantime.
{ ... }: {
  imports = [
    ./base.nix
    ../profiles/server.nix
  ];
}
