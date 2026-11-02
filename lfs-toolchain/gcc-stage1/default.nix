{ lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-gcc-stage1";
    version = "14.2.0";

    src = fetchurl {
        url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
        hash = "sha256-p7Obxpy/niWCbFpgqyZHcAH3wI2FzsBLwOKcq+1vPMk=";
    };

    buildInputs = [ gmp mpfr libmpc isl ];
    hardeningDisable = [ "format" ];

    dontAddPrefix = true;
    preConfigure = ''
        export PATH=${binutils}/tools/bin:$PATH
        # The host g++ 16 defaults to C++20, where u8"" literals are char8_t,
        # and libcody fails. g++ 14 defaults to gnu++17. Not CXXFLAGS: it
        # comes after the -std=c++11 that the libcody configure check adds.
        export CXX="g++ -std=gnu++17"
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
