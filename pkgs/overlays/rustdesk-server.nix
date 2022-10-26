{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "rustdesk-server";
  version = "1.1.6";

  src = fetchFromGitHub {
    owner = "rustdesk";
    repo = pname;
    rev = version;
    sha256 = "sha256-GFrdZx6xy6A7QrFh7UQuKbwFh+ZI0FL9LU2YwyEiyUs=";
  };

  cargoSha256 = "sha256-KIxjcXkbnF7fA+4rqZ5Jl29EAy++8D7lR48jfmsWhwY=";

  doInstallCheck = false;

  meta = with lib; {
    description = "RustDesk Server Program";
    homepage = "https://github.com/rustdesk/rustdesk-server";
    # license = with licenses; [ agpl ];
    maintainers = with maintainers; [kradalby];
    mainProgram = "hbbs";
  };
}
