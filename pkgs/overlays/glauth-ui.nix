{ pkgs, stdenv, mach-nix, ... }:
let
  glauthUi = builtins.fetchGit
    {
      url = "https://github.com/sonicnkt/glauth-ui";
      rev = "59e08004c252f3613a12f3f5f554b102a9d64ae1";
    };

  python =
    mach-nix.lib."aarch64-linux".mkPython {
      requirementsExtra = ''
        psycopg2
        gunicorn
      '';
      requirements = builtins.readFile "${glauthUi}/requirements.txt";
    };
in
stdenv.mkDerivation rec {
  pname = "glauth-ui";
  version = "0.0.1";
  src = glauthUi;


  gunicornScript = ''
    #!/bin/sh
    exec python -m gunicorn.app.wsgiapp "powerdnsadmin:create_app()" "$@"
  '';

  installPhase = ''
    runHook preInstall

    # Nasty hack: call wrapPythonPrograms to set program_PYTHONPATH (see tribler)
    wrapPythonPrograms

    mkdir -p $out/share $out/bin
    cp -r migrations powerdnsadmin $out/share/

    ln -s ${assets} $out/share/powerdnsadmin/static
    ln -s ${assetsPy} $out/share/powerdnsadmin/assets.py

    echo "$gunicornScript" > $out/bin/powerdns-admin
    chmod +x $out/bin/powerdns-admin
    wrapProgram $out/bin/powerdns-admin \
      --set PATH ${python.pkgs.python}/bin \
      --set PYTHONPATH $out/share:$program_PYTHONPATH

    runHook postInstall
  '';
}
