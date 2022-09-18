# Generated by pip2nix 0.8.0.dev1
# See https://github.com/nix-community/pip2nix

{ pkgs, fetchurl, fetchgit, fetchhg }:

self: super: {
  "paho-mqtt" = super.buildPythonPackage rec {
    pname = "paho-mqtt";
    version = "1.6.1";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/f8/dd/4b75dcba025f8647bc9862ac17299e0d7d12d3beadbf026d8c8d74215c12/paho-mqtt-1.6.1.tar.gz";
      sha256 = "0vy2xy78nqqqwbgk96cfrb5lgivjldc5ba5mf81w1bi32v4930ia";
    };
    format = "setuptools";
    doCheck = false;
    buildInputs = [];
    checkInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [];
  };
  "prometheus-client" = super.buildPythonPackage rec {
    pname = "prometheus-client";
    version = "0.14.1";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/19/e5/7d4b4b3b0d8d2fdc55395cdb4271c6dbfde3c3ff7d6a6dbe63d19c4e2288/prometheus_client-0.14.1-py3-none-any.whl";
      sha256 = "00fwahfrq64a7wz471jax2lba56z88plawr7ksl24a184pbdwbsj";
    };
    format = "wheel";
    doCheck = false;
    buildInputs = [];
    checkInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [];
  };
}
