{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  pname = "golines";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "segmentio";
    repo = "golines";
    rev = "v${version}";
    sha256 = "sha256-2K9KAg8iSubiTbujyFGN3yggrL+EDyeUCs9OOta/19A=";
  };

  vendorSha256 = "sha256-rxYuzn4ezAxaeDhxd8qdOzt+CKYIh03A9zKNdzILq18=";

  doCheck = false;

  nativeBuildInputs = [installShellFiles];
}
