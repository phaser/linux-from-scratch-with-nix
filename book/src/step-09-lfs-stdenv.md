# Step 9 — `lfsStdenv`

**File to write:** `lfs-stdenv/default.nix`, attribute `lfsStdenv`

A stdenv is a derivation that holds a shell, an `initialPath` of tools, a
wrapped compiler and `setup.sh`. You build one with
`pkgs/stdenv/generic/default.nix`. nixpkgs calls it in `stageFun`, in
`pkgs/stdenv/linux/default.nix`. Keep that function open while you write this
file.

**Nix concepts for this step**

New in this step:

- **Inside a stdenv.** `genericStdenv` (`pkgs/stdenv/generic`) makes a stdenv
  from parts: a `shell`, an `initialPath` (the tools on `PATH`), a `cc` and
  `extraNativeBuildInputs`. `pkgs.wrapCCWith` and `pkgs.wrapBintoolsWith` put a
  wrapper script around gcc and ld. The wrapper adds the flags for the libc.
  [More](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper).
- **`initialPath` and setup hooks.** A package in `initialPath` is only on
  `PATH`. A package in `extraNativeBuildInputs` also runs its setup hook. The
  patchelf hook needs the second. [More](appendix-nix-concepts.md#setup-hooks).
- **`import` of a nixpkgs file.** `import "${nixpkgs}/pkgs/stdenv/generic" { … }`
  reads a file from the nixpkgs source and calls its function.
  [More](appendix-nix-concepts.md#nix-language).
- **`with`.** `with temp; [ coreutils findutils ]` is
  `[ temp.coreutils temp.findutils ]`. [More](appendix-nix-concepts.md#nix-language).
- **Overlays.** nixpkgs can take a different stdenv for all of its packages.
  This book does not do that. [More](appendix-nix-concepts.md#fixed-points-and-overlays).

From earlier steps: [`inherit (x)`](appendix-nix-concepts.md#nix-language) (step 7), [setup hooks](appendix-nix-concepts.md#setup-hooks) (step 7), [hardening flags](appendix-nix-concepts.md#hardening-flags) (step 2).

---

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
  extraNativeBuildInputs = [ temp.patchelf ];
  inherit cc;
  preHook = "dontPatchShebangs=1";
}
```

`initialPath` only puts the tools on `PATH`. A package in
`extraNativeBuildInputs` also runs its setup hook in every build. The setup
hook of `temp.patchelf` (step 7) runs `patchelf --shrink-rpath` on each ELF
file in the fixup phase. nixpkgs does the same: `stageFun` gets
`extraNativeBuildInputs = [ prevStage.patchelf ]`. Without the hook, the
`RPATH` of each program keeps the gcc directories, and the runtime closure
gets `lfs-temp-gcc`. Step 10 checks this.

This uses the nixpkgs `wrapCCWith`, and those wrapper scripts run with the
*host* bash and coreutils. That is a known leak. You remove it in step 11.

The file needs `nixpkgs` (the flake input) and `temp`. Add the attribute to
the `rec` set in `flake.nix`, after `temp`, and run `git add lfs-stdenv`:

```nix
lfsStdenv = import ./lfs-stdenv { inherit pkgs nixpkgs temp; };
```

**Verify:**

```console
$ nix build .#lfsStdenv -o result-lfs-stdenv
$ ls result-lfs-stdenv                             # setup (and nix-support)
$ grep -o '/nix/store/[a-z0-9]*-lfs-temp-[a-z]*' result-lfs-stdenv/setup | sort -u
                                                   # the temp tools from initialPath
$ grep -o '[a-z0-9]*-lfs-temp-patchelf[^ "]*' result-lfs-stdenv/setup | sort -u
                                                   # ...-lfs-temp-patchelf-0.18.0 (in defaultNativeBuildInputs too)
$ nix path-info -r ./result-lfs-stdenv | grep -v -- '-lfs-'
                                                   # host bash, coreutils, gnugrep: the wrapper leak, expected now
$ nix why-depends ./result-lfs-stdenv <one-of-those-paths>
                                                   # the chain goes through the gcc wrapper
```
