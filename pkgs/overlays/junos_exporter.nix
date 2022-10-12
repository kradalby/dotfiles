{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:
buildGoModule rec {
  pname = "junos_exporter";
  version = "0.9.15";

  src = fetchFromGitHub {
    owner = "czerwonk";
    repo = pname;
    rev = "${version}";
    sha256 = "";
  };

  vendorSha256 = "";

  meta = with lib; {
    license = licenses.mit;
    maintainers = with maintainers; [kradalby];
  };
}
