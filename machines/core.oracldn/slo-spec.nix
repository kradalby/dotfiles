# The homelab SLO definitions, pure data — imported by slo.nix (build) and
# checks/prometheus-rules (unit tests) so both always compile the same spec.
let
  mkSLO = {
    name,
    description,
    objective,
    errorQuery,
    totalQuery,
    alertName,
  }: {
    inherit name description objective;
    sli.events = {
      error_query = errorQuery;
      total_query = totalQuery;
    };
    alerting = {
      name = alertName;
      page_alert.labels.severity = "critical";
      ticket_alert.labels.severity = "warning";
      annotations.summary = "${alertName}: burning error budget too fast";
    };
  };

  sloSpec = {
    version = "prometheus/v1";
    service = "homelab";
    labels.cluster = "homelab";
    slos = [
      # Public web edge, per vhost. "catch" is the default-server log, not a
      # real site. Only response_count/size carry data — the default combined
      # log format has no timing fields, so no latency SLI here.
      (mkSLO {
        name = "nginx-availability";
        description = "nginx 5xx ratio per vhost (headscale, kuma, umami, hvor, krapage, garnix edge)";
        objective = 99.5;
        errorQuery = ''sum by (vhost) (rate(nginxlog_http_response_count_total{vhost!="catch",status=~"5.."}[{{.window}}]))'';
        totalQuery = ''sum by (vhost) (rate(nginxlog_http_response_count_total{vhost!="catch"}[{{.window}}]))'';
        alertName = "NginxVhostErrorBudgetBurn";
      })

      # LAN DNS. SERVFAIL only — NXDOMAIN/REFUSED are usually correct answers.
      (mkSLO {
        name = "coredns-answers";
        description = "CoreDNS SERVFAIL ratio per site resolver";
        objective = 99.9;
        errorQuery = ''sum by (instance) (rate(coredns_dns_responses_total{rcode="SERVFAIL"}[{{.window}}]))'';
        totalQuery = ''sum by (instance) (rate(coredns_dns_responses_total[{{.window}}]))'';
        alertName = "CorednsErrorBudgetBurn";
      })

      # sqlite replication (headscale db, kuma.db, golink.db). Counter names
      # verified against litestream 0.5.11 source — no _total suffix there.
      (mkSLO {
        name = "litestream-sync";
        description = "litestream local sync error ratio per database";
        objective = 99.9;
        errorQuery = ''sum by (db) (rate(litestream_sync_error_count[{{.window}}]))'';
        totalQuery = ''sum by (db) (rate(litestream_sync_count[{{.window}}]))'';
        alertName = "LitestreamErrorBudgetBurn";
      })

      # The prom→receiver delivery leg. The external dead-man is the backstop
      # for the case where this alert itself can't be delivered.
      (mkSLO {
        name = "alertmanager-delivery";
        description = "Alertmanager notification failure ratio";
        objective = 99.0;
        errorQuery = ''sum(rate(alertmanager_notifications_failed_total[{{.window}}]))'';
        totalQuery = ''sum(rate(alertmanager_notifications_total[{{.window}}]))'';
        alertName = "AlertmanagerDeliveryErrorBudgetBurn";
      })

      # Blackbox probes: probe_success is a 0/1 gauge — _over_time, not rate.
      (mkSLO {
        name = "public-probes";
        description = "Public HTTPS endpoint availability (blackbox)";
        objective = 99.9;
        errorQuery = ''sum by (instance) (count_over_time(probe_success{job="https-probes"}[{{.window}}]) - sum_over_time(probe_success{job="https-probes"}[{{.window}}]))'';
        totalQuery = ''sum by (instance) (count_over_time(probe_success{job="https-probes"}[{{.window}}]))'';
        alertName = "PublicProbeErrorBudgetBurn";
      })
      (mkSLO {
        name = "tailnet-probes";
        description = "Tailnet-only service availability (blackbox) — convenience tier";
        objective = 99.0;
        errorQuery = ''sum by (instance) (count_over_time(probe_success{job="tailnet-probes"}[{{.window}}]) - sum_over_time(probe_success{job="tailnet-probes"}[{{.window}}]))'';
        totalQuery = ''sum by (instance) (count_over_time(probe_success{job="tailnet-probes"}[{{.window}}]))'';
        alertName = "TailnetProbeErrorBudgetBurn";
      })

      # Scrape success per job — the burn-rate replacement for a flappy
      # ExporterDown. `up` is synthesized even when the target is down, so
      # the counts are complete.
      (mkSLO {
        name = "scrape-success";
        description = "Prometheus scrape success ratio per job";
        objective = 99.9;
        errorQuery = ''sum by (job) (count_over_time(up[{{.window}}]) - sum_over_time(up[{{.window}}]))'';
        totalQuery = ''sum by (job) (count_over_time(up[{{.window}}]))'';
        alertName = "ScrapeErrorBudgetBurn";
      })

      # No headscale HTTP SLO: go-chi's http_requests_total is OPTIONS-only
      # (upstream Skip bug, not a config toggle) AND redundant — the control
      # plane is covered by native metrics already: HeadscaleMapResponseErrors
      # (headscale_mapresponse_sent_total{status="error"}), plus nodestore-empty,
      # queue-backlog and resource-exhaustion in monitoring.nix. No fork needed.
    ];
  };
in
  sloSpec
