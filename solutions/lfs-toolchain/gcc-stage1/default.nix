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

  # gcc's tarball does not include its prerequisites. LFS unpacks the gmp,
  # mpfr and mpc tarballs into the gcc source tree; here we point configure
  # at the copies nixpkgs already provides. LFS does not use isl.
  buildInputs = [ gmp mpfr libmpc isl ];

  # The cc-wrapper adds -Werror=format-security, and libcpp fails on it.
  # nixpkgs disables the same flag for its own gcc.
  hardeningDisable = [ "format" ];

  # The host g++ 16 defaults to C++20, where u8"" literals are char8_t, and
  # libcody fails. libcody configure adds -std=c++11, but the top-level
  # Makefile passes its own CXX and drops it. g++ 14 defaults to gnu++17.
  # Not NIX_CFLAGS_COMPILE: that also goes to C files.
  env.CXXFLAGS = "-g -O2 -std=gnu++17";

  # Divergence from LFS: in LFS, binutils and gcc share the $LFS/tools
  # prefix, so gcc finds ${triple}-as, -ld, -ar and -ranlib there. Here
  # binutils is a separate store path, and stdenv puts only $pkg/bin on
  # PATH, not $pkg/tools/bin. So:
  #   - PATH covers the build (top-level configure looks up the target
  #     ar, ranlib, nm and so on by name);
  #   - --with-as/--with-ld hardcode the tools into the installed driver,
  #     so `gcc -c` works later without binutils on PATH.
  dontAddPrefix = true;
  preConfigure = ''
    export PATH=${binutils}/tools/bin:$PATH
    mkdir -p build && cd build
  '';
  configureScript = "../configure";

  configureFlags = [
    "--target=${triple}"
    "--prefix=${placeholder "out"}/tools"
    "--with-as=${binutils}/tools/bin/${triple}-as"
    "--with-ld=${binutils}/tools/bin/${triple}-ld"

    "--with-gmp-include=${lib.getDev gmp}/include"
    "--with-gmp-lib=${lib.getLib gmp}/lib"
    "--with-mpfr-include=${lib.getDev mpfr}/include"
    "--with-mpfr-lib=${lib.getLib mpfr}/lib"
    "--with-mpc-include=${lib.getDev libmpc}/include"
    "--with-mpc-lib=${lib.getLib libmpc}/lib"
    "--with-isl-include=${lib.getDev isl}/include"
    "--with-isl-lib=${lib.getLib isl}/lib"

    # Divergences from LFS pass 1, which also passes --with-sysroot=$LFS,
    # --with-glibc-version, --enable-default-pie and --enable-default-ssp,
    # and builds c,c++. There is no sysroot yet (rung 4 creates one), and
    # this rung only needs a C compiler that emits objects.
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
