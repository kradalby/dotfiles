{ pkgs, herdrSource }:
pkgs.herdr.overrideAttrs (_old: {
  # The package fileset omits fixtures referenced by the upstream unit harness.
  src = herdrSource;
  doCheck = true;
  checkFlags = [ "codex_native_selection" ];
})
