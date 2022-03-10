{ buildGoModule, fetchFromGitHub, lib, installShellFiles }:
buildGoModule rec {
  pname = "golines";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "segmentio";
    repo = "golines";
    rev = "v${version}";
    sha256 = "sha256-W4vN3rGKyX43HZyjjVUKnR4Fy0LfYqVf6h7wIYO0U50=";
  };

  vendorSha256 = "sha256-ZHL2hQnJXpZu42hQZzIIaEzINSS+5BOL9dxAVCp0nMs=";

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];
}
