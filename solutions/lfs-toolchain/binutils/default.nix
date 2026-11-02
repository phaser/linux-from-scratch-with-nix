{ lib, stdenv, fetchurl, triple }:

# Rung 1 — binutils for the target triple.
#
# Built with the *host's* compiler, which is allowed and expected: this is
# LFS pass 1. The result is a cross assembler/linker that runs on the build
# machine and produces code for the target triple.
#
# Check after building:
#   $out/tools/bin/${triple}-ld --version

stdenv.mkDerivation rec {
  pname = "lfs-binutils";
  version = "2.43";

  src = fetchurl {
    url = "mirror://gnu/binutils/binutils-${version}.tar.xz";
    hash = lib.fakeHash; # build once, copy the `got:` hash
  };

  dontAddPrefix = true;
  preConfigure = "mkdir -p build && cd build";
  configureScript = "../configure";

  # Divergence from LFS pass 1, which also passes --with-sysroot=$LFS and
  # --enable-new-dtags. There is no sysroot yet; rung 4 creates one.
  configureFlags = [
    "--target=${triple}"
    "--prefix=${placeholder "out"}/tools"
    "--disable-nls"
    "--disable-werror" # new host compilers add warnings; LFS does this too
    "--disable-gprofng"
    "--enable-default-hash-style=gnu"
  ];

  meta = {
    description = "binutils for ${triple}, built from source";
    platforms = lib.platforms.linux;
  };
}
