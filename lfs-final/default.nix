# Step 11: every package again, built by your own stdenvs.
{ pkgs, nixpkgs, toolchain, temp, lfsStdenv }:

let
  # The stdenv of step 9, with other parts (part 2a).
  mkStdenv = args: import ../lfs-stdenv ({ inherit pkgs nixpkgs temp; } // args);
in
rec {
  # Stage 1: built by lfsStdenv.
  glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };

  # Stage 2: temporary binutils and gcc, final glibc.
  lfsStdenvFinalGlibc = mkStdenv { name = "lfs-stdenv-final-glibc"; libc = glibc; };

  # Sample compilation 1.
  helloFinalGlibc = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalGlibc; };

  binutils = pkgs.callPackage ./binutils { stdenv = lfsStdenvFinalGlibc; inherit (toolchain) triple; };
  gcc = pkgs.callPackage ./gcc { stdenv = lfsStdenvFinalGlibc; inherit glibc; inherit (toolchain) triple; };

  # The final glibc, binutils and gcc. The other tools are still lfs-temp-*.
  lfsStdenvFinalToolchain = mkStdenv {
    name = "lfs-stdenv-final-toolchain";
    libc = glibc;
    inherit binutils gcc;
  };

  # Sample compilation 2.
  helloFinalToolchain = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalToolchain; };

  # Stage 3: built by lfsStdenvFinalToolchain.
  coreutils = pkgs.callPackage ./coreutils { stdenv = lfsStdenvFinalToolchain; };
  gnumake   = pkgs.callPackage ./gnumake   { stdenv = lfsStdenvFinalToolchain; };
  bash      = pkgs.callPackage ./bash      { stdenv = lfsStdenvFinalToolchain; };
  gnused    = pkgs.callPackage ./gnused    { stdenv = lfsStdenvFinalToolchain; };
  gnugrep   = pkgs.callPackage ./gnugrep   { stdenv = lfsStdenvFinalToolchain; };
  gawk      = pkgs.callPackage ./gawk      { stdenv = lfsStdenvFinalToolchain; };
  findutils = pkgs.callPackage ./findutils { stdenv = lfsStdenvFinalToolchain; };
  diffutils = pkgs.callPackage ./diffutils { stdenv = lfsStdenvFinalToolchain; };
  gnupatch  = pkgs.callPackage ./gnupatch  { stdenv = lfsStdenvFinalToolchain; };
  gnutar    = pkgs.callPackage ./gnutar    { stdenv = lfsStdenvFinalToolchain; };
  gzip      = pkgs.callPackage ./gzip      { stdenv = lfsStdenvFinalToolchain; };
  xz        = pkgs.callPackage ./xz        { stdenv = lfsStdenvFinalToolchain; };
  bzip2     = pkgs.callPackage ./bzip2     { stdenv = lfsStdenvFinalToolchain; };
  patchelf  = pkgs.callPackage ./patchelf  { stdenv = lfsStdenvFinalToolchain; };

  # Stage 4: a program of the wrappers, built by your toolchain.
  expand-response-params = pkgs.callPackage
    "${nixpkgs}/pkgs/by-name/ex/expand-response-params/package.nix"
    { stdenv = lfsStdenvFinalToolchain; };
}
