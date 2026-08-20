{
  pkgs,
  self,
  ...
}:
let
  # The exact rules core.oracldn deploys: inline rule groups from its config,
  # plus the sloth burn-rate rules recompiled from the same spec (sloth
  # generate is pure, so this matches the aarch64 build bit-for-bit).
  inlineRules = pkgs.writeText "rules.json" (
    builtins.head self.nixosConfigurations.core-oracldn.config.services.prometheus.rules
  );

  yaml = pkgs.formats.yaml { };
  sloSpec = yaml.generate "homelab-slos.yaml" (import ../../machines/core.oracldn/slo-spec.nix);
  slothRules = pkgs.runCommand "sloth-rules.yaml" { nativeBuildInputs = [ pkgs.sloth ]; } ''
    sloth generate -i ${sloSpec} -o $out
  '';

  # Alerts that predate the "an alert with no test is not done" convention.
  # This list may only shrink: a NEW inline alert without a promtool test fails
  # the check (add a case to tests.yaml), and an entry here that has since been
  # tested or removed must be deleted from this list. Chip away at it over time.
  grandfatheredUntested = pkgs.writeText "grandfathered-untested.txt" (
    builtins.concatStringsSep "\n" [
      "AlertmanagerConfigReloadFailed"
      "CPUPressure"
      "ConntrackNearLimit"
      "ExporterDown"
      "FileDescriptorsNearLimit"
      "GarageUnhealthy"
      "HeadscaleNodestoreEmpty"
      "HeadscaleQueueBacklog"
      "HeadscaleResourceExhaustion"
      "HighCPULoad"
      "HttpsProbeDown"
      "HttpsProbeSlow"
      "HypervisorHighCPU"
      "HypervisorLowDisk"
      "HypervisorLowMem"
      "IncusDaemonDown"
      "IncusDaemonRestarted"
      "IncusInstanceMemoryPressure"
      "IncusInstanceNetworkErrors"
      "IncusInstanceOOMKill"
      "IncusInstanceSwapHigh"
      "IncusVMVanished"
      "InstanceLowBootDiskAbs"
      "InstanceLowDiskAbs"
      "InstanceLowDiskPerc"
      "InstanceLowDiskPrediction12Hours"
      "InstanceLowMem"
      "LitestreamReplicaOpErrors"
      "LitestreamVerifyErrors"
      "MemoryPressure"
      "NetworkInterfaceErrors"
      "NginxLogParseErrors"
      "OOMKill"
      "PostfixQueueBacklog"
      "PostgreSQLDown"
      "PostgreSQLHighConnections"
      "PostgresqlBackupStale"
      "PrometheusNotificationErrors"
      "PrometheusRuleEvalFailures"
      "PrometheusTSDBErrors"
      "ProtonBridgeLoginFailing"
      "PushgatewayGroupStale"
      "ResticBackupStale"
      "ResticBackupStaleJotta"
      "ResticRepoNoNewSnapshots"
      "RusticBackupMetricsMissing"
      "RusticBackupStale"
      "SMARTDiskTemperature"
      "SMARTDiskUnhealthy"
      "ServiceFlapping"
      "ServiceRestartLoop"
      "SfiberProxyDown"
      "SmokepingPacketLoss"
      "SmokepingTargetDown"
      "SwapThrash"
      "SyncthingFolderConflicts"
      "SyncthingFolderError"
      "SyncthingFolderStuck"
      "SyncthingNoConnections"
      "TailnetServiceDown"
      "TailscaledRouteApprovalPending"
      "TimeMachineFlatline"
      "TjodaPingDown"
      "TlsCertExpiringSoon"
      "TlsCertExpiryCritical"
      "Ts1pOpAuthFailed"
      "TsnixcacheDiskFull"
      "TsnixcacheGCErrors"
      "ZFSPoolMissing"
      "ZFSPoolSpaceCritical"
      "ZFSPoolSpaceWarning"
      "ZFSPoolUnhealthy"
    ]
  );
in
pkgs.runCommand "prometheus-rule-tests"
  {
    nativeBuildInputs = [
      pkgs.prometheus.cli
      pkgs.jq
    ];
  }
  ''
    substitute ${./tests.yaml} tests.yaml \
      --subst-var-by rules ${inlineRules} \
      --subst-var-by sloth ${slothRules}
    promtool check rules ${inlineRules} ${slothRules}
    promtool test rules tests.yaml

    # Enforce docs/conventions/services.md: every inline alert carries a test.
    jq -r '.groups[].rules[] | select(.alert) | .alert' ${inlineRules} | sort -u >alerts.txt
    grep -oE 'alertname: [A-Za-z0-9]+' tests.yaml | awk '{print $2}' | sort -u >tested.txt
    sort -u ${grandfatheredUntested} >allow.txt
    comm -23 alerts.txt tested.txt >untested.txt

    new=$(comm -23 untested.txt allow.txt)
    if [ -n "$new" ]; then
      echo "These alerts have no promtool test in checks/prometheus-rules/tests.yaml:" >&2
      echo "$new" >&2
      echo "Add a test case (an alert with no test is not done), or grandfather it in default.nix." >&2
      exit 1
    fi

    stale=$(comm -13 untested.txt allow.txt)
    if [ -n "$stale" ]; then
      echo "These alerts are grandfathered but are now tested or removed — delete them from default.nix:" >&2
      echo "$stale" >&2
      exit 1
    fi

    touch $out
  ''
