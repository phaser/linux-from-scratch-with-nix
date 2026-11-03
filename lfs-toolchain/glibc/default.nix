{
  lib,
  stdenv,
  fetchurl,
  bison,
  python3,
  perl,
  binutils,
  gccStage1,
  headers,
  triple,
}:

stdenv.mkDerivation rec {
  pname = "lfs-glibc";
  version = "2.40";

  nativeBuildInputs = [
    bison
    python3
    perl
  ];

  src = fetchurl {
    url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
    hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
  };

  hardeningDisable = [ "format" ];
  dontAddPrefix = true;
  preConfigure = ''
    export PATH=${binutils}/tools/bin:${gccStage1}/tools/bin:$PATH;
    # stdenv exports CC=gcc (the host gcc 16), AR=ar, and others. configure
    # takes them over the ${triple}-* tools on PATH, so unset them.
    unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP
    # dontStrip keeps the -g debug info. Its .debug_line_str section records
    # the include directories of gcc stage 1 and the kernel headers as store
    # paths. Nix then sees them as runtime references, and the closure pulls
    # in gcc stage 1 and its host libraries (gcc 16, gmp, isl). Rewrite the
    # prefixes to plain names. glibc needs -O2, so CFLAGS must keep it.
    export CFLAGS="-g -O2 -fdebug-prefix-map=${gccStage1}=/gcc-stage1 -fdebug-prefix-map=${headers}=/linux-headers"
    echo "rootsbindir=/usr/sbin" > configparms
    mkdir -p build && cd build
  '';
  configureScript = "../configure";
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

  meta = {
    description = "glibc for ${triple}, built from source";
    platforms = lib.platforms.linux;
  };
}
