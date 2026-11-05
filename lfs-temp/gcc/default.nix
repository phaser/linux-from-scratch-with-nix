# Step 8c: the step 6 file, changed as the table says.
{ lib, fetchurl, mkTemp, glibc, triple }:

let
  gmp  = fetchurl { url = "mirror://gnu/gmp/gmp-6.3.0.tar.bz2";
                    hash = "sha256-rCghGnz7YJuuLiyNYFjWbI/pZDT3QM9v4uR7AA0cIMs="; };
  mpfr = fetchurl { url = "mirror://gnu/mpfr/mpfr-4.2.2.tar.xz";
                    hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE="; };
  mpc  = fetchurl { url = "mirror://gnu/mpc/mpc-1.4.1.tar.xz";
                    hash = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE="; };
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

    patches = [ ./no-sys-dirs.patch ];
    hardeningDisable = [ "format" ];

    preConfigure = ''
        export CXX_FOR_BUILD="g++ -std=gnu++17"
        export LDFLAGS_FOR_BUILD=
        mkdir -p build && cd build
    '';
    configureScript = "../configure";

    configureFlags = [
        "--target=${triple}"
        "--with-native-system-header-dir=${glibc}/include"
        "--with-glibc-version=${glibc.version}"
        "--enable-languages=c,c++"
        "--disable-nls"
        "--disable-multilib"
        "--disable-bootstrap"
        "--disable-lto"
        "--disable-plugin"
        "--disable-libsanitizer"
    ];

    postInstall = ''
      cat ../gcc/limitx.h ../gcc/glimits.h ../gcc/limity.h \
        > $out/lib/gcc/${triple}/${version}/include/limits.h
      rm -r $out/libexec/gcc/${triple}/${version}/install-tools
    '';

    meta.platforms = lib.platforms.linux;
}
