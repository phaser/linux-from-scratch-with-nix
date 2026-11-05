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
}
