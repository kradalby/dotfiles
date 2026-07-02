{lib, ...}: {
  imports = [
    ../../common/nginx.nix
    ../../common/acme.nix # ACME DNS-01 via Cloudflare
  ];

  # Single TLS terminator: nginx owns 80/443 on wan0, backends speak plain HTTP.
  # mkForce drops common/nginx.nix's globally-open nginxlog exporter port — on a
  # public box metrics must not face wan0 (still scrapable over tailscale/bridge).
  # SSH is gated in networking.nix, not here.
  networking.firewall.allowedTCPPorts = lib.mkForce [80 443];

  # Attr name is the domain; modules/vhost.nix provisions the ACME cert + vhost.
  services.vhost = {
    # local host service:  "foo.kradalby.no".proxyPass = "http://127.0.0.1:8080";
    # VM service (static IP in 10.68.10.0/24):
    #                      "bar.kradalby.no".proxyPass = "http://10.68.10.5:8080";
    "garnix.kradalby.no".proxyPass = "http://10.68.10.10:80";
  };

  # No cert for the bare public IP: lego puts the IP in the CSR Common Name and LE
  # rejects that (IP certs need an empty CN, IP in SAN only). Domain vhosts use
  # DNS-01 and are unaffected. Revisit if lego gains IP-SAN support.
}
