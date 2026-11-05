# Written from the book text of step 4.
{ lib, stdenv, fetchurl, bison, python3, perl, binutils, gccStage1, headers, triple }:

stdenv.mkDerivation rec {
  pname = "lfs-glibc";
  version = "2.40";

  src = fetchurl {
    url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
    hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
  };

  nativeBuildInputs = [ bison python3 perl ];

  preConfigure = ''
    export PATH=${gccStage1}/tools/bin:${binutils}/tools/bin:$PATH
    unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP
    export CFLAGS="-g -O2 -fdebug-prefix-map=${gccStage1}=/gcc-stage1 -fdebug-prefix-map=${headers}=/linux-headers"
    mkdir build && cd build
    echo "rootsbindir=/usr/sbin" > configparms
  '';

  configureScript = "../configure";
  dontAddPrefix = true;
  configurePlatforms = [ ];
  configureFlags = [
    "--prefix=/usr"
    "--host=${triple}"
    "--build=${stdenv.buildPlatform.config}"
    "--enable-kernel=4.19"
    "--with-headers=${headers}/usr/include"
    "--disable-nscd"
    "libc_cv_slibdir=/usr/lib"
  ];

  installFlags = [ "DESTDIR=${placeholder "out"}" ];
  dontStrip = true;
  dontPatchELF = true;
  dontPatchShebangs = true;
}
