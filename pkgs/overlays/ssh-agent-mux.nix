{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "ssh-agent-mux";
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "overhacked";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Sd/F4ft2gQYj8nj4lQMbwkwlB3VNt/byI82+ySZSQGY=";
  };

  cargoHash = "sha256-o/7BWBvwgnqEAKCa63jmuT8ma6pmC+7SYHxUUKTPxNM=";

  # Tests require ssh-agent which isn't available in the build sandbox
  doCheck = false;

  meta = with lib; {
    description = "Combine keys from multiple SSH agents into a single agent socket";
    homepage = "https://github.com/overhacked/ssh-agent-mux";
    license = with licenses; [asl20 bsd3];
    maintainers = [maintainers.kradalby];
    mainProgram = "ssh-agent-mux";
  };
}
