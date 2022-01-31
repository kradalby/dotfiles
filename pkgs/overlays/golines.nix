{ buildGoModule, fetchFromGitHub, lib, installShellFiles }:
buildGoModule rec {
  pname = "golines";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "segmentio";
    repo = "golines";
    rev = "v${version}";
    sha256 = "sha256-FlpZ8UTPC3HOjNgkTWgsZUZ5tOm+rqQFedUkN/rgQXg=";
  };

  vendorSha256 = "sha256-ZHL2hQnJXpZu42hQZzIIaEzINSS+5BOL9dxAVCp0nMs=";
  # vendorSha256 = "sha256-A50ntz6nSpBKb6/ifqAdYbUo/RN8M3emhzq3Qq4Wjpw=";

  doCheck = false;

  # subPackages = [ "cmd/golangci-lint" ];

  nativeBuildInputs = [ installShellFiles ];

  # ldflags = [
  #   "-s" "-w" "-X main.version=${version}" "-X main.commit=v${version}" "-X main.date=19700101-00:00:00"
  # ];

  # postInstall = ''
  #   for shell in bash zsh fish; do
  #     HOME=$TMPDIR $out/bin/golangci-lint completion $shell > golangci-lint.$shell
  #     installShellCompletion golangci-lint.$shell
  #   done
  # '';

  # meta = with lib; {
  #   description = "Fast linters Runner for Go";
  #   homepage = "https://golangci-lint.run/";
  #   license = licenses.gpl3Plus;
  #   maintainers = with maintainers; [ anpryl manveru mic92 ];
  # };
}
