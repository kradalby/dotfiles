{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  pname = "imapchive";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "calmh";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-ky475aOiwdmAPr//u/STtE77FC8tQjmkpYsEq7wzXyg=";
  };

  vendorSha256 = "sha256-8kNhXuLhNRqApGkvy2qn16TwnflUFVGCoqied0pfb1w=";

  doCheck = false;

  nativeBuildInputs = [installShellFiles];
}
