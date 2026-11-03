{ pkgs, toolchain }:

let
    mkTemp = import ./lib.nix {
        inherit (pkgs) stdenv;
        inherit (toolchain) triple binutils gccStage2;
    };
    call = dir: pkgs.callPackage dir { inherit mkTemp; };
in rec {
    gnumake     = call ./gnumake;
    coreutils   = call ./coreutils;
    bash        = call ./bash;
    gnused      = call ./gnused;
    gnugrep     = call ./gnugrep;
    gawk        = call ./gawk;
    findutils   = call ./findutils;
    patchelf    = call ./patchelf;

    tools = pkgs.buildEnv {
        name = "lfs-temp-tools";
        paths = [ gnumake coreutils bash gnused gnugrep gawk findutils patchelf ];
    };
}
