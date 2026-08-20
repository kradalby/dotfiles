# Fail the build if something exposes a metrics/monitoring surface but nothing
# watches it — the complement of the absent() canaries (which catch a *known*
# target going silent). Two coverage rules, both pure eval against the deployed
# configs, no runtime:
#
#   1. every enabled `services.prometheus.exporters.<name>` on any host has a
#      scrape job on core.oracldn that targets it;
#   2. every NixOS host has a node_exporter scrape (i.e. is in `allHosts`).
#
# A new exporter or host that nobody monitors fails CI until it is either wired
# up or explicitly allowlisted below with a reason — that decision is the point.
{
  pkgs,
  self,
  ...
}:
let
  lib = pkgs.lib;
  cfgs = self.nixosConfigurations;

  # Hosts are aliased under both dotted and dashed names; scrape targets use the
  # dashed form, so drive off those and skip the dotted duplicates.
  hostNames = lib.filter (h: !(lib.hasInfix "." h)) (builtins.attrNames cfgs);

  # --- what IS monitored: core.oracldn's prometheus scrape targets ---
  scrapeConfigs = cfgs.core-oracldn.config.services.prometheus.scrapeConfigs;
  targetsOf = job: lib.concatMap (sc: sc.targets or [ ]) (job.static_configs or [ ]);
  monitoredTargets = lib.unique (lib.concatMap targetsOf scrapeConfigs);

  nodesJob = lib.findFirst (j: j.job_name == "nodes") null scrapeConfigs;
  monitoredHosts =
    if nodesJob == null then [ ] else map (t: lib.head (lib.splitString ":" t)) (targetsOf nodesJob);

  # --- what IS exposed: enabled standard prometheus exporters per host ---
  # tryEval guards removed/renamed exporter options that throw on access. Custom exporters (services.<name>-exporter) are out of scope here —
  # they are hand-wired, so the "flip enable, forget the scrape" failure this
  # rule targets does not apply to them.
  enabledExporters =
    host:
    let
      exps = cfgs.${host}.config.services.prometheus.exporters;
    in
    lib.filter (x: x != null) (
      map (
        n:
        let
          en = builtins.tryEval (exps.${n}.enable or false);
        in
        if en.success && en.value then
          let
            p = builtins.tryEval (exps.${n}.port or null);
          in
          {
            name = n;
            port = if p.success then p.value else null;
          }
        else
          null
      ) (builtins.attrNames exps)
    );

  # --- allowlist: deliberately exposed without a scrape target. Each entry
  # needs a reason; forcing that decision is the whole value of this check. ---
  exemptExporters = {
    blackbox = "the prober itself — used via /probe by the blackbox probe jobs, never scraped as a target";
  };
  exemptHosts = {
    # "core-terra" = "decommissioned; commented out of the scrape host lists";
  };

  isMonitored =
    host: port:
    port != null
    && (
      lib.elem "${host}:${toString port}" monitoredTargets
      || (
        host == "core-oracldn"
        && (
          lib.elem "localhost:${toString port}" monitoredTargets
          || lib.elem "127.0.0.1:${toString port}" monitoredTargets
        )
      )
    );

  exporterGaps = lib.concatMap (
    host:
    lib.concatMap (
      e:
      if (exemptExporters ? ${e.name}) || e.port == null || isMonitored host e.port then
        [ ]
      else
        [
          "${host}: prometheus.exporters.${e.name} (:${toString e.port}) is enabled but no scrape job targets it"
        ]
    ) (enabledExporters host)
  ) hostNames;

  hostGaps = lib.concatMap (
    host:
    if (exemptHosts ? ${host}) || lib.elem host monitoredHosts then
      [ ]
    else
      [ "${host}: NixOS host has no node_exporter scrape (add it to allHosts)" ]
  ) hostNames;

  # --- VIP services: every services.tailscale.services.<name> must be watched
  # (scraped or probed) or allowlisted. services.md makes the VIP the preferred
  # reachability tier and promises "a service nothing watches fails CI". ---
  vipNames = lib.unique (
    lib.concatMap (
      host: builtins.attrNames (cfgs.${host}.config.services.tailscale.services or { })
    ) hostNames
  );

  # host-part of a scrape/probe target: strip scheme, path and port.
  #   "http://pdf.dalby.ts.net" -> "pdf.dalby.ts.net"
  #   "syncthing-ldn:80"        -> "syncthing-ldn"
  targetHost =
    t:
    let
      afterScheme = lib.last (lib.splitString "//" t);
      beforePath = lib.head (lib.splitString "/" afterScheme);
    in
    lib.head (lib.splitString ":" beforePath);
  targetHosts = map targetHost monitoredTargets;

  # Watched if a target is the VIP by name (host:port) or by MagicDNS FQDN
  # (<vip>.dalby.ts.net…). Exact, so a substring can't mask a real gap.
  vipWatched = name: lib.any (h: h == name || lib.hasPrefix "${name}." h) targetHosts;

  exemptVips = {
    "prom" = "scraped locally on core-oracldn (localhost:9090), not by VIP name";
    "alertmanager" = "scraped locally on core-oracldn (localhost:9093), not by VIP name";
    "pushgateway" = "scraped locally on core-oracldn (localhost:9091), not by VIP name";
    "atuin" = "scraped by backing host dev-oracfurt:8889, not by VIP name";
    "proton-bridge" =
      "login-probe pushes proton_bridge_* to the pushgateway; no direct scrape (see monitoring.nix)";
    # TODO: give these a blackbox probe and drop the exemption.
    "p3" = "TODO: no liveness probe yet — add a blackbox target for the p3-controller web UI";
    "zigbee2mqtt-ldn" =
      "TODO: no liveness probe yet — add a blackbox target for the zigbee2mqtt frontend";
  };

  vipGaps = lib.concatMap (
    name:
    if (exemptVips ? ${name}) || vipWatched name then
      [ ]
    else
      [
        "${name}: services.tailscale.services VIP has no scrape/probe (add one or allowlist with a reason)"
      ]
  ) vipNames;

  # --- vipBacking sanity: every relabel that rewrites `target` to a literal
  # host must name a real host, so a typo can't silently break inhibition. ---
  # Some jobs carry relabel_configs = null (not absent), so `or []` isn't
  # enough. Include metric_relabel_configs too: resticTargetRelabels — named
  # in this check's own error message — live there on the pushgateway job.
  relabelsOf =
    sc:
    let
      norm = v: if v == null then [ ] else v;
    in
    norm (sc.relabel_configs or [ ]) ++ norm (sc.metric_relabel_configs or [ ]);
  literalTargetReplacements = lib.unique (
    lib.concatMap (
      sc:
      lib.concatMap (
        rc:
        let
          rawRepl = rc.replacement or "";
          repl = if rawRepl == null then "" else rawRepl;
        in
        if
          (rc.target_label or "") == "target" && repl != "" && !(lib.hasInfix "$" repl) # skip regex back-references like $1
        then
          [ repl ]
        else
          [ ]
      ) (relabelsOf sc)
    ) scrapeConfigs
  );
  backingGaps = lib.concatMap (
    repl:
    if lib.elem repl hostNames then
      [ ]
    else
      [
        "target relabel rewrites to '${repl}', which is not a NixOS host (stale vipBacking/resticTargetRelabels entry?)"
      ]
  ) literalTargetReplacements;

  gaps = exporterGaps ++ hostGaps ++ vipGaps ++ backingGaps;
  gapReport = lib.concatMapStrings (g: "echo '  - ${g}' >&2\n") gaps;
in
pkgs.runCommand "monitoring-coverage" { } (
  if gaps == [ ] then
    "echo 'monitoring-coverage: every enabled exporter is scraped and every host is onboarded' >&2; touch $out"
  else
    ''
      echo 'monitoring-coverage: found surfaces nothing watches. Add a scrape/probe, or allowlist with a reason in checks/monitoring-coverage/default.nix:' >&2
      ${gapReport}
      exit 1
    ''
)
