{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "tasmota-exporter";
  # NOTE: manual update required
  # https://github.com/dyrkin/tasmota-exporter/tree/master
  version = "b4be44d467920327c0c33f93edf22ca3fc3b75ea";

  src = fetchFromGitHub {
    owner = "dyrkin";
    repo = "tasmota-exporter";
    rev = "${version}";
    sha256 = "sha256-i6BIp7e0kxSk0URGiP7se1HwGM02O2t2K7ypLsIGWIM=";
  };
  vendorHash = "sha256-MKGZuDiZGN7JHKzWyY+sy+m78LOP9i5cp+qRXZOD3Gg=";
  CGO_ENABLED = 0;
  subPackages = ["cmd"];
  doCheck = false;
}
