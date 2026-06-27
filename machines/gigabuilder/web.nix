{lib, ...}: {
  imports = [
    ../../common/nginx.nix # nginx + recommended proxy/TLS, nginxlog exporter
    ../../common/acme.nix # ACME DNS-01 via Cloudflare (cloudflare-token secret)
  ];

  # Single TLS terminator. nginx owns 80/443 on wan0; backends (local services
  # and Incus VMs) speak plain HTTP over loopback / incusbr0.
  #
  # mkForce drops the globally-open nginxlog exporter port that common/nginx.nix
  # adds to allowedTCPPorts — on a public box metrics must never face wan0. It
  # stays scrapable over tailscale0/incusbr0, both already trustedInterfaces.
  # SSH is unaffected (networking.nix gates it via extraInputRules, not this list).
  networking.firewall.allowedTCPPorts = lib.mkForce [80 443];

  # Proxy a service in one line — attr name is the domain, ACME cert + vhost are
  # provisioned by modules/vhost.nix. Local vs VM differ only in proxyPass.
  services.vhost = {
    # local service on the host:
    # "foo.kradalby.no".proxyPass = "http://127.0.0.1:8080";

    # service in an Incus VM (give the VM a static IP in 10.68.10.0/24):
    # "bar.kradalby.no".proxyPass = "http://10.68.10.5:8080";

    # garnix CI coordinator (VM at 10.68.10.10, serves plain HTTP). Public
    # GitHub webhook → this TLS terminator → VM. Uncomment with the garnix box.
    # "garnix.kradalby.no".proxyPass = "http://10.68.10.10:80";
  };

  # Let's Encrypt cert for the public IP itself (reachable without DNS). Can't go
  # through services.vhost: IP certs require the shortlived profile + HTTP-01
  # (DNS-01 is rejected for IP identifiers), so override the cloudflare DNS-01
  # default per-cert. nginx auto-serves /.well-known/acme-challenge because
  # dnsProvider == null.
  security.acme.certs."194.32.107.146" = {
    profile = "shortlived"; # ~6d cert; security.acme renews at half-life
    dnsProvider = null; # force HTTP-01 (port 80) — DNS-01 not allowed for IPs
    webroot = "/var/lib/acme/acme-challenge"; # lego writes the challenge here
  };

  services.nginx.virtualHosts."194.32.107.146" = {
    serverName = "194.32.107.146";
    useACMEHost = "194.32.107.146";
    forceSSL = true;
    acmeRoot = "/var/lib/acme/acme-challenge"; # nginx serves the challenge from here
    # serves whatever should answer on the bare IP, e.g. a status page or proxy:
    # locations."/".proxyPass = "http://127.0.0.1:8080";
  };
}
