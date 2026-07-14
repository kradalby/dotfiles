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
  # tryEval guards removed/renamed exporter options (e.g. `minio`) that throw on
  # access. Custom exporters (services.<name>-exporter) are out of scope here —
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

  gaps = exporterGaps ++ hostGaps;
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
