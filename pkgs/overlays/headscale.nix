{ lib, buildGoModule, fetchFromGitHub, installShellFiles }:

buildGoModule rec {
  pname = "headscale";
  version = "0.13.0-beta3";

  src = fetchFromGitHub {
    # owner = "juanfont";
    owner = "kradalby";
    repo = "headscale";
    # rev = "v${version}";
    # sha256 = "sha256-TBCTfAWJcpl6tew03P1mTb7cQClBBNFJllXusjTMuwc=";
    rev = "56b6528e3b3125d460437c22529d381b7f311b7d";
    sha256 = "sha256-V5BEbM2ajLKl9Oelv84WCGLpbE4XGe9EzkXw7ME3Sqg=";
  };

  # proxyVendor = true;
  vendorSha256 = "sha256-xRQ0M363eyPxwC3wNeCXsqxxp3bBT4evyFD0eO0Izmg=";

  ldflags = [ "-s" "-w" "-X github.com/juanfont/headscale/cmd/headscale/cli.Version=v${version}" ];

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
    maintainers = with maintainers; [ nkje jk ];
  };
}

