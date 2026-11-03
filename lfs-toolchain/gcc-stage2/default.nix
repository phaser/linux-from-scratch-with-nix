{ lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, sysroot, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-gcc-stage2";
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

        "--with-sysroot=${sysroot}"
        "--with-native-system-header-dir=/usr/include"
        "--enable-languages=c,c++"
        "--disable-nls"
        "--disable-multilib"
        "--disable-bootstrap"
    ];

    meta = {
        description = "stage-2 C/C++ compiler for ${triple}";
        platforms = lib.platforms.linux;
    };
}
