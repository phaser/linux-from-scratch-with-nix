{ pkgs, nixpkgs, toolchain, final, lfsStdenvFinal }:

rec {
    kernel = pkgs.callPackage ./kernel {
        stdenv = lfsStdenvFinal;
        inherit (toolchain.headers) src version;
    };
}
