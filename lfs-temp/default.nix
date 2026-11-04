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
    diffutils   = call ./diffutils;
    gnupatch    = call ./gnupatch;
    gnutar      = call ./gnutar;
    gzip        = call ./gzip;
    xz          = call ./xz;
    bzip2       = pkgs.callPackage ./bzip2 { inherit mkTemp; inherit (toolchain) triple; };
    patchelf    = call ./patchelf;

    temp-glibc      = pkgs.callPackage ./glibc { inherit (toolchain) triple binutils headers gccStage2; }; 
    temp-binutils   = pkgs.callPackage ./binutils { inherit mkTemp; inherit (toolchain) triple; };
    temp-gcc        = pkgs.callPackage ./gcc {
        inherit mkTemp;
        inherit (toolchain) triple;
        glibc = temp-glibc;
    };
    tools = pkgs.buildEnv {
        name = "lfs-temp-tools";
        paths = [ gnumake coreutils bash gnused gnugrep gawk findutils diffutils gnupatch gnutar gzip xz bzip2 patchelf ];
    };
}
