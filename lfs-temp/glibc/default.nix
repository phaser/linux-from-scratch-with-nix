# Step 8a, from the step 4 file and the book text.
{ lib, stdenv, fetchurl, bison, python3, perl, binutils, gccStage2, headers, triple }:

stdenv.mkDerivation rec {
  pname = "lfs-temp-glibc";
  version = "2.40";

  src = fetchurl {
    url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
    hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
  };

  nativeBuildInputs = [ bison python3 perl ];

  preConfigure = ''
    export PATH=${gccStage2}/tools/bin:${binutils}/tools/bin:$PATH
    unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP
    export CFLAGS="-g -O2 -fdebug-prefix-map=${gccStage2}=/gcc-stage2 -fdebug-prefix-map=${headers}=/linux-headers"
    mkdir build && cd build
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

  postInstall = ''
    for d in ${headers}/usr/include/*; do
      [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
    done
  '';

  dontStrip = true;
  dontPatchELF = true;
  dontPatchShebangs = true;
}
