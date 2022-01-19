{ pkgs, lib, ... }:
with lib;
let
  recursiveMerge = attrList:
    let f = attrPath:
      zipAttrsWith (n: values:
        if tail values == [ ]
        then head values
        else if all isList values
        then unique (concatLists values)
        else if all isAttrs values
        then f (attrPath ++ [ n ]) values
        else last values
      );
    in f [ ] attrList;


  writeSwift = name: { swiftcArgs ? [ ]
                     , strip ? true
                     }:
    # let
    #   darwinArgs = lib.optionals stdenv.isDarwin [ "-L${lib.getLib libiconv}/lib" ];
    # in
    # ${lib.escapeShellArgs darwinArgs}
    pkgs.writers.makeBinWriter
      {
        compileScript = ''
          cp "$contentPath" tmp.swift
          PATH=${makeBinPath [pkgs.gcc]} /usr/bin/swiftc ${lib.escapeShellArgs swiftcArgs} -o "$out" tmp.swift
        '';
        inherit strip;
      }
      name;

  writeSwiftBin = name:
    writeSwift "/bin/${name}";

  swiftMacOSWrapper = command:
    writeSwift "swift-wrapper" { } ''
      import Foundation
      import os
      import IOKit.ps

      let home = ProcessInfo.processInfo.environment["HOME"]

      let isPowerAdapterConnected = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() != nil

      func shell(_ command: String) {
          let task = Process()

          print("Executing: ${command}")

          task.arguments = ["-c", command]
          task.launchPath = "/bin/bash"
          do {
              try task.run()
          } 
          catch {
              print(error)
          }
          task.waitUntilExit()
      }

      if isPowerAdapterConnected {
          shell("${command}")
      } else {
          print("On battery power, skipping...")
      }
    '';
in
{ inherit recursiveMerge swiftMacOSWrapper; }
