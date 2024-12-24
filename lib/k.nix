{...}: {
  tailscaleHostname = cfg: builtins.replaceStrings [".fap.no" "."] ["" "-"] cfg.networking.fqdn;
}
