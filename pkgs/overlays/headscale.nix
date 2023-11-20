{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:
buildGoModule rec {
  pname = "headscale";
  version = "0.17.0";

  src = fetchFromGitHub {
    # owner = "juanfont";
    owner = "kradalby";
    repo = "headscale";
    # rev = "v${version}";
    rev = "33ae56acfaf96d6e4d3e8d15c91868b47ba5ed6c";
    sha256 = "sha256-bmalF5NnXjXzyF8WIIN8burmaYYeZwzDIFoNrZAXX8I=";
  };

  vendorHash = "sha256-kc8EU+TkwRlsKM2+ljm/88aWe5h2QMgd/ZGPSgdd9QQ=";

  ldflags = ["-s" "-w" "-X github.com/juanfont/headscale/cmd/headscale/cli.Version=v${version}-${src.rev}"];

  nativeBuildInputs = [installShellFiles];

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
    maintainers = with maintainers; [kradalby];
  };
}
