{ pkgs }:

# The whole bootstrap, as a DAG of derivations.
#
# Read this file last. Each stage lives in its own file so you can read one
# rung of the ladder at a time, the way LFS presents them.

let
  inherit (pkgs) lib callPackage;

  # The vendor "lfs" is deliberately fake. It makes the triple distinct from
  # the host's, which is what stops the host toolchain from being reused by
  # accident. "unknown" works too; LFS uses "lfs" so that nobody can mistake
  # it for a real vendor.
  triple = "aarch64-lfs-linux-gnu";

  binutils = callPackage ./binutils.nix { inherit triple; };
  gccStage1 = callPackage ./gcc-stage1.nix { inherit triple binutils; };
  headers = callPackage ./headers.nix { };
  # glibc and gccStage2 are the design exercise — see README.md, rung 4.
in {
  inherit binutils gccStage1 headers;
}
