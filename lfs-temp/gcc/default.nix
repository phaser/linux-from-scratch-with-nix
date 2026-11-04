{ fetchurl, mkTemp, triple, glibc }:

let
    # LFS chapter 6 builds these inside the gcc tree, so gcc stage 2 compiles
    # them for the target. The nixpkgs gmp, mpfr and libmpc are host binaries.
    gmp = fetchurl {
        url = "mirror://gnu/gmp/gmp-6.3.0.tar.bz2";
        hash = "sha256-rCghGnz7YJuuLiyNYFjWbI/pZDT3QM9v4uR7AA0cIMs=";
    };
    mpfr = fetchurl {
        url = "mirror://gnu/mpfr/mpfr-4.2.2.tar.xz";
        hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
    };
    mpc = fetchurl {
        url = "mirror://gnu/mpc/mpc-1.4.1.tar.xz";
        hash = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE=";
    };
in
mkTemp rec {
    pname = "gcc";
    version = "14.2.0";

    src = fetchurl {
        url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
        hash = "sha256-p7Obxpy/niWCbFpgqyZHcAH3wI2FzsBLwOKcq+1vPMk=";
    };

    postUnpack = ''
        tar -xf ${gmp}  -C $sourceRoot && mv $sourceRoot/gmp-*  $sourceRoot/gmp
        tar -xf ${mpfr} -C $sourceRoot && mv $sourceRoot/mpfr-* $sourceRoot/mpfr
        tar -xf ${mpc}  -C $sourceRoot && mv $sourceRoot/mpc-*  $sourceRoot/mpc
    '';

    # A native gcc searches /usr/local/include, /lib and /usr/lib. This
    # patch removes them. It does not remove /usr/include: see below.
    patches = [ ./no-sys-dirs.patch ];

    # For the host-built programs, as in stage 2.
    hardeningDisable = [ "format" ];

    preConfigure = ''
        # build != host, so the programs that run during the build (genmodes,
        # gengtype ...) use the host compiler. g++ 16 defaults to C++20.
        export CXX_FOR_BUILD="g++ -std=gnu++17"
        # LDFLAGS_FOR_BUILD defaults to LDFLAGS (-static), and the host glibc
        # has no libc.a. Set it, empty.
        export LDFLAGS_FOR_BUILD=
        mkdir -p build && cd build
    '';
    configureScript = "../configure";

    # mkTemp gives --host=${triple}. With --target the same, gcc is native.
    configureFlags = [
        "--target=${triple}"
        # The default is /usr/include. Use the glibc of step 8a.
        "--with-native-system-header-dir=${glibc}/include"
        "--enable-languages=c,c++"
        "--disable-nls"
        "--disable-multilib"
        "--disable-bootstrap"
        "--disable-lto"
        "--disable-plugin"
        "--disable-libsanitizer"
    ];

    # build != host and no build sysroot: gcc looks for the glibc limits.h in
    # $out/${triple}/sys-include, finds nothing, and installs a limits.h that
    # does not include it. Write the full one, as LFS chapter 5 does.
    postInstall = ''
        cat ../gcc/limitx.h ../gcc/glimits.h ../gcc/limity.h \
            > $out/lib/gcc/${triple}/${version}/include/limits.h
    '';
}
