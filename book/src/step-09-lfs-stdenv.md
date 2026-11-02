# Step 9 — `lfsStdenv`

**File to write:** `lfs-stdenv/default.nix`, attribute `lfsStdenv`

A stdenv is a derivation that holds a shell, an `initialPath` of tools, a
wrapped compiler and `setup.sh`. You build one with
`pkgs/stdenv/generic/default.nix`. nixpkgs calls it in `stageFun`, in
`pkgs/stdenv/linux/default.nix`. Keep that function open while you write this
file.

**Do:**

```nix
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
  initialPath = with temp; [ coreutils findutils diffutils gnused gnugrep gawk
                             gnutar gzip xz bzip2 gnumake bash gnupatch patchelf ];
  fetchurlBoot = import "${nixpkgs}/pkgs/build-support/fetchurl/boot.nix" {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (pkgs.config) rewriteURL;
  };
  inherit cc;
  preHook = "dontPatchShebangs=1";
}
```

This uses the nixpkgs `wrapCCWith`, and those wrapper scripts run with the
*host* bash and coreutils. That is a known leak. You remove it in step 11.

The file needs `nixpkgs` (the flake input) and `temp`. Pass both from
`flake.nix`.

**Verify:**

```console
$ nix build .#lfsStdenv -o result-lfs-stdenv
$ ls result-lfs-stdenv                             # setup (and nix-support)
$ grep -o '/nix/store/[a-z0-9]*-lfs-temp-[a-z]*' result-lfs-stdenv/setup | sort -u
                                                   # the temp tools from initialPath
$ nix path-info -r ./result-lfs-stdenv | grep -v -- '-lfs-'
                                                   # host bash, coreutils, gnugrep: the wrapper leak, expected now
$ nix why-depends ./result-lfs-stdenv <one-of-those-paths>
                                                   # the chain goes through the gcc wrapper
```

**Nix concepts:** [the stdenv internals](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper),
[`import` of nixpkgs files](appendix-nix-concepts.md#nix-language), [overlays and fixed points](appendix-nix-concepts.md#fixed-points-and-overlays).
