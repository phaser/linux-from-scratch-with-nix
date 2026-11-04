{ pkgs, nixpkgs, temp }:
let
    inherit (pkgs) lib;
    genericStdenv = import "${nixpkgs}/pkgs/stdenv/generic" { defaultConfig = pkgs.config; };
    libc = temp.glibc;
    bintools = pkgs.wrapBintoolsWith { bintools = temp.binutils; inherit libc; };
    cc = pkgs.wrapCCWith { cc = temp.gcc; inherit bintools libc; };
in
genericStdenv {
    name = "lfs-stdenv";
    inherit (pkgs.stdenv) buildPlatform hostPlatform targetPlatform;
    config = pkgs.config;
    shell = "${temp.bash}/bin/bash";
    initialPath = with temp; [
        coreutils
        findutils
        diffutils
        gnused
        gnugrep
        gawk
        gnutar
        gzip
        xz
        bzip2
        gnumake
        bash
        gnupatch
        patchelf
    ];

    fetchurlBoot = import "${nixpkgs}/pkgs/build-support/fetchurl/boot.nix" {
        inherit (pkgs.stdenv.hostPlatform) system;
        inherit (pkgs.config) rewriteURL;
    };
    # The setup hook of patchelf shrinks the RPATH of each ELF file, as in
    # nixpkgs (extraNativeBuildInputs = [ prevStage.patchelf ]).
    extraNativeBuildInputs = [ temp.patchelf ];
    inherit cc;
    preHook = "dontPatchShebangs=1";
}
