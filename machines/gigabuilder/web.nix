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
    # GitHub webhook → this TLS terminator → VM.
    "garnix.kradalby.no".proxyPass = "http://10.68.10.10:80";
  };

  # NOTE: no Let's Encrypt cert for the bare IP. HTTP-01 validation succeeds, but
  # lego puts the IP in the CSR Common Name and LE rejects that
  # (badCSR: "CSR contains IP address in Common Name") — IP certs require an
  # empty CN with the IP only in the SAN, which this lego can't emit. Revisit
  # when lego gains IP-SAN support. Domain vhosts use DNS-01 and are unaffected.
}
