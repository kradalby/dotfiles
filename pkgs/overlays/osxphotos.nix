{pkgs, ...}: let
  mach-nix =
    import (builtins.fetchGit {
      url = "https://github.com/DavHau/mach-nix";
      ref = "refs/tags/3.5.0";
      rev = "7e14360bde07dcae32e5e24f366c83272f52923f";
    }) {
      inherit pkgs;
      # python = "python38";
    };

  version = "v0.55.5";
in
  mach-nix.buildPythonPackage {
    pname = "osxphotos";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "RhetTbull";
      repo = "osxphotos";
      rev = version;
      sha256 = "sha256-w/fDqP+h36mubl3zailN3ESkBdRGUPDWum6x/dVPHWM=";
    };

    requirements = ''
      Click>=8.0.4,<9.0s
      Mako>=1.2.2,<1.3.0
      PyYAML>=6.0.0,<7.0.0
      bitmath>=1.3.3.1,<1.4.0.0
      bpylist2==4.0.1
      more-itertools>=8.8.0,<9.0.0
      objexplore>=1.6.3,<2.0.0
      osxmetadata>=1.2.0,<2.0.0
      packaging>=21.3
      pathvalidate>=2.4.1,<2.5.0
      photoscript>=0.2.1,<0.3.0
      ptpython>=3.0.20,<3.1.0
      pyobjc-core>=9.0,<10.0
      pyobjc-framework-AVFoundation>=9.0,<10.0
      pyobjc-framework-AppleScriptKit>=9.0,<10.0
      pyobjc-framework-AppleScriptObjC>=9.0,<10.0
      pyobjc-framework-Cocoa>=9.0,<10.0
      pyobjc-framework-CoreServices>=9.0,<10.0
      pyobjc-framework-Metal>=9.0,<10.0
      pyobjc-framework-Photos>=9.0,<10.0
      pyobjc-framework-Quartz>=9.0,<10.0
      pyobjc-framework-Vision>=9.0,<10.0
      pytimeparse2==1.4.0
      requests>=2.27.1,<3.0.0
      rich>=11.2.0,<13.0.0
      rich_theme_manager>=0.11.0
      shortuuid==1.0.9
      strpdatetime>=0.2.0
      tenacity>=8.0.1,<9.0.0
      textx>=3.0.0,<4.0.0
      toml>=0.10.2,<0.11.0
      wrapt>=1.14.1,<2.0.0
      wurlitzer>=3.0.2,<4.0.0
      xdg==5.1.1
    '';
  }
