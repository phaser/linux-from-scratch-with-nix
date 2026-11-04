# Step 11: every package again, built by your own stdenvs.
{ pkgs, toolchain, lfsStdenv }:

rec {
    # Stage 1: built by lfsStdenv.
    glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };
}
