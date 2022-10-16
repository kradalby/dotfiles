{
  lib,
  pkgs,
  fetchFromGitHub,
  fetchpatch,
  python3Packages,
}: let
  packageOverrides = pkgs.callPackage ./python-packages.nix {};
  python = pkgs.python310.override {inherit packageOverrides;};
  pythonWithPackages =
    python.withPackages (ps: [
    ]);
in
  python3Packages.buildPythonApplication rec {
    pname = "glauth-ui";
    version = "220304";

    format = "other";

    src = fetchFromGitHub {
      owner = "sonicnkt";
      repo = pname;
      rev = "59e08004c252f3613a12f3f5f554b102a9d64ae1";
      sha256 = "";
    };

    patches = with packageOverrides; [
      pkgs.python310Packages.psycopg2
      Bootstrap-Flask
      Flask
      Flask-Admin
      Flask-Login
      Flask-Mail
      Flask-Migrate
      Flask-SQLAlchemy
      Flask-WTF
      Jinja2
      Mako
      MarkupSafe
      PyJWT
      SQLAlchemy
      WTForms
      Werkzeug
      alembic
      blinker
      click
      dnspython
      email-validator
      greenlet
      idna
      itsdangerous
      python-dotenv
    ];

    propagatedBuildInputs = [
    ];

    meta = with lib; {
      description = "Glauth UI";
      maintainers = with maintainers; [kradalby];
      platforms = platforms.all;
    };
  }
