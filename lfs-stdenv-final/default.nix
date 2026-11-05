# Stage 4: the stdenv of step 9, with only lfs-final-* packages.
{ pkgs, nixpkgs, temp, final }:
let
    genericStdenv = import "${nixpkgs}/pkgs/stdenv/generic" { defaultConfig = pkgs.config; };
    libc = final.glibc;

    # The wrapper scripts run these programs. If you do not give them,
    # wrapCCWith and wrapBintoolsWith take the nixpkgs packages.
    wrapperTools = {
        inherit (final) coreutils gnugrep expand-response-params;
        runtimeShell = "${final.bash}/bin/bash";
    };
    bintools = pkgs.wrapBintoolsWith ({ bintools = final.binutils; inherit libc; } // wrapperTools);
    cc = pkgs.wrapCCWith ({ cc = final.gcc; inherit bintools libc; } // wrapperTools);
in
genericStdenv {
    name = "lfs-stdenv-final";
    inherit (pkgs.stdenv) buildPlatform hostPlatform targetPlatform;
    config = pkgs.config;
    shell = "${final.bash}/bin/bash";
    initialPath = with final; [
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
    extraNativeBuildInputs = [ final.patchelf ];
    inherit cc;
    preHook = "dontPatchShebangs=1";

    # The build of the stdenv fails if it refers to one of these packages.
    disallowedRequisites = builtins.attrValues temp
        ++ (with pkgs; [ runtimeShellPackage coreutils gnugrep expand-response-params ]);
}
