{ stdenv, fetchurl, triple, glibc }:

let
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
stdenv.mkDerivation rec {
    pname = "lfs-final-gcc";
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

    # The same patch as step 8c.
    patches = [ ../../lfs-temp/gcc/no-sys-dirs.patch ];
    hardeningDisable = [ "format" ];

    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";

    configurePlatforms = [ ];
    configureFlags = [
        "--build=${triple}"
        "--host=${triple}"
        "--target=${triple}"
        "--with-native-system-header-dir=${glibc}/include"
        "--enable-languages=c,c++"
        "--disable-nls"
        "--disable-multilib"
        "--disable-bootstrap"
        "--disable-lto"
        "--disable-plugin"
        "--disable-libsanitizer"
    ];

    # gcc compiles libgcc and libstdc++ with its new xgcc. xgcc has no
    # wrapper. Give it the final glibc, as nixpkgs does
    # (pkgs/development/compilers/gcc/common/builder.nix).
    preBuild = ''
        tflags="-B${glibc}/lib -idirafter ${glibc}/include"
        lflags="-Wl,-L${glibc}/lib -Wl,-rpath,${glibc}/lib -Wl,-dynamic-linker=${glibc}/lib/ld-linux-aarch64.so.1"
        makeFlagsArray+=(
            "FLAGS_FOR_TARGET=$tflags $lflags"
            "CFLAGS_FOR_TARGET=-O2 $tflags $lflags"
            "CXXFLAGS_FOR_TARGET=-O2 $tflags $lflags"
            "LDFLAGS_FOR_TARGET=$lflags"
        )
    '';

    # As in step 8c: these scripts store paths of the build tools.
    postInstall = ''
        rm -r $out/libexec/gcc/${triple}/${version}/install-tools
    '';
}

