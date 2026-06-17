{
  buildGoModule,
  fetchFromGitHub,
  libffi,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildGoModule rec {
    pname = "ghostty-tab";
    # Upstream is github.com/seruman/boo (binary "boo"); renamed locally to
    # ghostty-tab so the `boo` name is free for the coder/boo multiplexer.
    # NOTE: manual update required
    # https://github.com/seruman/boo/commits/main/
    version = versions.pkgs.overlays.ghostty-tab;

    src = fetchFromGitHub {
      owner = "seruman";
      repo = "boo";
      rev = "${version}";
      hash = "sha256-A2dURovCnEvp3u/1NGuOHAt77iw6cli0ZdsFUL4uU0o=";
    };
    vendorHash = "sha256-sfiu7FrcbyUcYhfyXa4RU73Zg0S0Gi2KNaQqmwygJzo=";

    buildInputs = [
      libffi
    ];

    # boo uses darwinkit which requires CGo for Objective-C bridging.
    env = {
      CGO_ENABLED = 1;
    };

    # Upstream installs the binary as `boo`; rename it so it does not clash
    # with the coder/boo multiplexer that now owns the `boo` command.
    postInstall = ''
      mv $out/bin/boo $out/bin/ghostty-tab
    '';

    meta = {
      description = "CLI tool to control Ghostty terminal via AppleScript";
      homepage = "https://github.com/seruman/boo";
      mainProgram = "ghostty-tab";
    };
  }
