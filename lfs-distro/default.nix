{ pkgs, nixpkgs, toolchain, final, lfsStdenvFinal }:

rec {
    kernel = pkgs.callPackage ./kernel {
        stdenv = lfsStdenvFinal;
        inherit (toolchain.headers) src version;
    };
    busybox = (pkgs.busybox.override { stdenv = lfsStdenvFinal; }).overrideAttrs {
      pname = "lfs-final-busybox";
      depsBuildBuild = [ ];
    };
    sysenv = pkgs.callPackage ./sysenv {
        inherit final busybox;
        cc = lfsStdenvFinal.cc;
    };
    etc = pkgs.callPackage ./etc { };
    init = pkgs.callPackage ./init { inherit final; };
    initrd = pkgs.callPackage ./initrd { inherit init sysenv etc; };
    rootImage = pkgs.callPackage ./root-image { inherit nixpkgs sysenv etc; };
}
