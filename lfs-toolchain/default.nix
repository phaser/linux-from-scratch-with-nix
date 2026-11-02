{ pkgs }:

# Your cross toolchain: steps 1 to 6 of the book.
#
# Write each component in its own directory, as <name>/default.nix, and add
# one attribute for it below. The book's checks use these attribute names:
#
#   step 1  binutils     ./binutils
#   step 2  gccStage1    ./gcc-stage1
#   step 3  headers      ./linux-headers
#   step 4  glibc        ./glibc
#   step 5  sysroot      ./sysroot
#   step 6  gccStage2    ./gcc-stage2
#
# When step 6 works, add a `toolchain` attribute that builds all of them.
# The answer key for steps 1 to 3 is in ../solutions/lfs-toolchain/.

let
  inherit (pkgs) callPackage;
  triple = "aarch64-lfs-linux-gnu";
in
{
  binutils = callPackage ./binutils { inherit triple; };
}

