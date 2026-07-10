{
  config,
  lib,
  ...
}: {
  # gigabuilder is the fleet's outbound SMTP relay. Every host sends to
  # smtp.fap.no (which resolves here, over the tailnet); gigabuilder relays out
  # through gigahost with SMTP AUTH. Keeps mail off each host's own egress and
  # gives one place to hold gigahost credentials.
  #
  # NEEDS: secrets/gigahost-smtp.age — a texthash map, one line:
  #   [smtp.gigahost.no]:587 <gigahost-smtp-user>:<gigahost-smtp-password>
  # and, if gigahost rejects mismatched senders, the authorised From address
  # (set senderCanonical below to it). Until the secret is filled + this host
  # deployed, outbound mail queues here instead of leaving.
  services.postfix.settings.main = {
    # Break the smtp.fap.no -> gigabuilder loop from common/postfix.nix.
    relayhost = lib.mkForce ["[smtp.gigahost.no]:587"];

    # Accept relay from the tailnet (CGNAT v4 + tailscale ULA v6) + localhost.
    mynetworks = [
      "127.0.0.0/8"
      "[::1]/128"
      "100.64.0.0/10"
      "[fd7a:115c:a1e0::]/48"
    ];
    inet_interfaces = "all";

    # gigahost SMTP AUTH over TLS. texthash reads the plaintext secret map
    # directly — no postmap/.db, so the agenix path works as-is.
    smtp_sasl_auth_enable = true;
    smtp_sasl_password_maps = "texthash:${config.age.secrets.gigahost-smtp.path}";
    smtp_sasl_security_options = "noanonymous";
    smtp_sasl_tls_security_options = "noanonymous";
    smtp_tls_security_level = "encrypt";

    # gigahost likely requires the envelope sender to be the authenticated
    # account. If so, uncomment and point at that address:
    #   sender_canonical_maps = "regexp:${./gigahost-sender-canonical}";
  };

  # NOTE: keep :25 tailnet-only — do NOT add it to networking.firewall's public
  # allowedTCPPorts, or gigabuilder becomes an open relay. mynetworks already
  # scopes who may relay; the firewall must not widen it.

  age.secrets.gigahost-smtp = {
    file = ../../secrets/gigahost-smtp.age;
    owner = "root";
  };
}
