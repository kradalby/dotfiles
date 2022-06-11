{ lib, buildGoModule, fetchFromGitHub, installShellFiles }:

buildGoModule rec {
  pname = "headscale";
  version = "0.16.0-beta3";

  src = fetchFromGitHub {
    owner = "juanfont";
    # owner = "kradalby";
    repo = "headscale";
    rev = "v${version}";
    # rev = "adb55bcfe9f84bd93a333293a1e5702ff4d9cee9";
    sha256 = "sha256-n9Nvorhm/SGWcopwnMpFOU8D0jaB1Om+nevcbO+keM8=";
  };

  vendorSha256 = "sha256-b6qPOO/NmcXsAsSRWZlYXZKyRAF++DsL4TEZzRhQhME=";

  ldflags = [ "-s" "-w" "-X github.com/juanfont/headscale/cmd/headscale/cli.Version=v${version}-${src.rev}" ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd headscale \
      --bash <($out/bin/headscale completion bash) \
      --fish <($out/bin/headscale completion fish) \
      --zsh <($out/bin/headscale completion zsh)
  '';

  meta = with lib; {
    homepage = "https://github.com/juanfont/headscale";
    description = "An open source, self-hosted implementation of the Tailscale control server";
    longDescription = ''
      Tailscale is a modern VPN built on top of Wireguard. It works like an
      overlay network between the computers of your networks - using all kinds
      of NAT traversal sorcery.
      Everything in Tailscale is Open Source, except the GUI clients for
      proprietary OS (Windows and macOS/iOS), and the
      'coordination/control server'.
      The control server works as an exchange point of Wireguard public keys for
      the nodes in the Tailscale network. It also assigns the IP addresses of
      the clients, creates the boundaries between each user, enables sharing
      machines between users, and exposes the advertised routes of your nodes.
      Headscale implements this coordination server.
    '';
    license = licenses.bsd3;
    maintainers = with maintainers; [ kradalby ];
  };
}
