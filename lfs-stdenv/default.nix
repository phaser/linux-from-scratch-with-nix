{ pkgs, nixpkgs, temp,
  name ? "lfs-stdenv",
  libc ? temp.glibc,
  binutils ? temp.binutils,
  gcc ? temp.gcc }:
let
  inherit (pkgs) lib;
  genericStdenv = import "${nixpkgs}/pkgs/stdenv/generic" { defaultConfig = pkgs.config; };
  bintools = pkgs.wrapBintoolsWith { bintools = binutils; inherit libc; };
  cc = pkgs.wrapCCWith { cc = gcc; inherit bintools libc; };
in
genericStdenv {
  inherit name;
  inherit (pkgs.stdenv) buildPlatform hostPlatform targetPlatform;
  config = pkgs.config;
  shell = "${temp.bash}/bin/bash";
  initialPath = with temp; [ coreutils findutils diffutils gnused gnugrep gawk
                             gnutar gzip xz bzip2 gnumake bash gnupatch patchelf ];
  fetchurlBoot = import "${nixpkgs}/pkgs/build-support/fetchurl/boot.nix" {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (pkgs.config) rewriteURL;
  };
  extraNativeBuildInputs = [ temp.patchelf ];
  inherit cc;
  preHook = "dontPatchShebangs=1";
}
