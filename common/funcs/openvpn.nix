{ config, pkgs, lib }:
let
  server = site: {

    age.secrets.ca.file = ../../secrets/ca.age;
    age.secrets."ovpn-${site.name}-crt".file = ../../secrets + "/ovpn-${site.name}-crt.age";
    age.secrets."ovpn-${site.name}-key".file = ../../secrets + "/ovpn-${site.name}-key.age";

    networking.firewall = {
      trustedInterfaces = [ "tun200" ];
    };

    services.openvpn.servers.server = {
      config =
        ''
          # server
          proto tcp
          local 0.0.0.0
          port 1194

          key ${config.age.secrets."ovpn-${site.name}-key".path}
          cert ${config.age.secrets."ovpn-${site.name}-crt".path}
          ca ${config.age.secrets.ca.path}

          # Hardening
          # https://blog.securityevaluators.com/hardening-openvpn-in-2020-1672c3c4135a

          # remote-cert-eku "TLS Web Client Authentication"
          # tls-crypt myvpn.tlsauth
          socket-flags TCP_NODELAY #if using TCP, uncomment this to reduce latency
          float #accept authenticated packets from any IP to allow clients to roam
          keepalive 10 60 #send keepalive pings every 10 seconds, disconnect clients after 60 seconds of no traffic
          opt-verify #reject clients with mismatched settings

          #data channel cipher
          cipher AES-256-GCM

          tls-server
          tls-cert-profile preferred
          tls-version-min 1.3
          tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384

          # disable static Diffie-Hellman parameters since we're using ECDHE
          dh none
          ecdh-curve secp384r1 # use the NSA's recommended curve

          # network
          dev tun200
          topology subnet
          server ${site.openvpn} 255.255.255.0

          push "redirect-gateway def1"
          ${
            lib.concatMapStringsSep "\n"
            (dns: ''push "dhcp-option DNS ${dns}"'')
            site.nameservers
          }
          push "block-outside-dns"
        '';
    };
  };
in
{
  inherit server;
}
