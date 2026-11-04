{
  lib,
  stdenv,
  fetchurl,
  bison,
  python3,
  perl,
  binutils,
  gccStage2,
  headers,
  triple,
}:

stdenv.mkDerivation rec {
  pname = "lfs-temp-glibc";
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
  preConfigure = ''
    export PATH=${binutils}/tools/bin:${gccStage2}/tools/bin:$PATH;

    # stdenv exports CC=gcc (the host gcc 16), AR=ar, and others. configure
    # takes them over the ${triple}-* tools on PATH, so unset them.
    unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP
    
    # dontStrip keeps the -g debug info. Its .debug_line_str section records
    # the include directories of gcc stage 1 and the kernel headers as store
    # paths. Nix then sees them as runtime references, and the closure pulls
    # in gcc stage 1 and its host libraries (gcc 16, gmp, isl). Rewrite the
    # prefixes to plain names. glibc needs -O2, so CFLAGS must keep it.
    export CFLAGS="-g -O2 -fdebug-prefix-map=${gccStage2}=/gcc-stage2 -fdebug-prefix-map=${headers}=/linux-headers"
    mkdir -p build && cd build
  '';
  configureScript = "../configure";
  configurePlatforms = [ ];
  configureFlags = [
    "--host=${triple}"
    "--build=${stdenv.buildPlatform.config}"
    "--enable-kernel=4.19"
    "--with-headers=${headers}/usr/include"
    "--disable-nscd"
  ];
  dontStrip = true;
  dontPatchELF = true;
  dontPatchShebangs = true;

  postInstall = ''
    for d in ${headers}/usr/include/*; do
        [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
    done
  '';

  meta = {
    description = "glibc for ${triple}, built from source";
    platforms = lib.platforms.linux;
  };
}
