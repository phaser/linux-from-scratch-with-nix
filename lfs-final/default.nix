# Step 11: every package again, built by your own stdenvs.
{ pkgs, nixpkgs, toolchain, temp, lfsStdenv }:

let
    mkStdenv = args: import ../lfs-stdenv ({ inherit pkgs nixpkgs temp; } // args);
in rec {
    # Stage 1: built by lfsStdenv.
    glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };

    lfsStdenvFinalGlibc = mkStdenv { name = "lfs-stdenv-final-glibc"; libc = glibc; };

    helloFinalGlibc = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalGlibc; };
}
