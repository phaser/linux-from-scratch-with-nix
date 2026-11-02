{ lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, triple }:

# Rung 2 — a C compiler that can emit object files but cannot link.
#
# The point of this stage is the chicken-and-egg problem: you need a compiler
# to build libc, and libc to link anything. So this gcc is configured with
# --without-headers --with-newlib, which tells it "assume no libc exists".
# It produces .o files. That is success at this rung.
#
# Check after building:
#   echo 'int main(){return 0;}' > hello.c
#   $out/tools/bin/${triple}-gcc -c hello.c     # must produce hello.o
#   $out/tools/bin/${triple}-gcc hello.c        # must FAIL, no libc yet

stdenv.mkDerivation rec {
  pname = "lfs-gcc-stage1";
  version = "14.2.0";

  src = fetchurl {
    url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
    hash = lib.fakeHash;
  };

  # gcc's tarball does not include its prerequisites. LFS runs
  # contrib/download_prerequisites, which needs the network; in a sandbox we
  # point configure at the copies nixpkgs already provides.
  buildInputs = [ gmp mpfr libmpc isl ];
  # binutils must be on PATH so configure finds ${triple}-as and ${triple}-ld.
  nativeBuildInputs = [ binutils ];

  dontAddPrefix = true;
  preConfigure = "mkdir -p build && cd build";
  configureScript = "../configure";

  configureFlags = [
    "--target=${triple}"
    "--prefix=${placeholder "out"}/tools"

    "--with-gmp-include=${lib.getDev gmp}/include"
    "--with-gmp-lib=${lib.getLib gmp}/lib"
    "--with-mpfr-include=${lib.getDev mpfr}/include"
    "--with-mpfr-lib=${lib.getLib mpfr}/lib"
    "--with-mpc-include=${lib.getDev libmpc}/include"
    "--with-mpc-lib=${lib.getLib libmpc}/lib"
    "--with-isl-include=${lib.getDev isl}/include"
    "--with-isl-lib=${lib.getLib isl}/lib"

    "--with-newlib"
    "--without-headers"
    "--enable-languages=c"
    "--disable-nls"
    "--disable-shared"
    "--disable-multilib"
    "--disable-threads"
    "--disable-libatomic"
    "--disable-libgomp"
    "--disable-libquadmath"
    "--disable-libssp"
    "--disable-libvtv"
    "--disable-libstdcxx"
    "--disable-bootstrap"
  ];

  meta = {
    description = "stage-1 C compiler for ${triple}";
    platforms = lib.platforms.linux;
  };
}
