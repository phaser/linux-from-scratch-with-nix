{ pkgs }:

# Answer key for Part 1 of the book (steps 1 to 3). Read it only after you
# wrote your own lfs-toolchain/. Steps 4 to 6 have no answer key yet.
#
# Each component lives in its own directory, with a default.nix.

let
  inherit (pkgs) callPackage linkFarm;

  # The vendor "lfs" is deliberately fake. It makes the triple distinct from
  # the host's, which is what stops the host toolchain from being reused by
  # accident. "unknown" works too; LFS uses "lfs" so that nobody can mistake
  # it for a real vendor.
  triple = "aarch64-lfs-linux-gnu";

  binutils = callPackage ./binutils { inherit triple; };
  gccStage1 = callPackage ./gcc-stage1 { inherit triple binutils; };
  headers = callPackage ./linux-headers { };
in
{
  inherit binutils gccStage1 headers;

  # `nix build .#solutions.toolchain` builds every component above.
  toolchain = linkFarm "lfs-toolchain" [
    { name = "binutils"; path = binutils; }
    { name = "gcc-stage1"; path = gccStage1; }
    { name = "linux-headers"; path = headers; }
  ];
}
