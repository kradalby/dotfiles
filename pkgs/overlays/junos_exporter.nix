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
    sha256 = "sha256-SvvK9G/t7ytlyyNm2es8HqXPsOC3MeXHdqu9xvsQCt8=";
  };

  vendorSha256 = "sha256-nCduTvBVXiUG7r+FyPRRgriBMhygNS9DFe9aVHnHtYo=";

  meta = with lib; {
    license = licenses.mit;
    maintainers = with maintainers; [kradalby];
  };
}
