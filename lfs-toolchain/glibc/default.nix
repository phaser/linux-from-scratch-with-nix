{
  lib,
  stdenv,
  fetchurl,
  bison,
  python3,
  perl,
  binutils,
  gccStage1,
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
    hash = lib.fakeHash;
  };

  dontAddPrefix = true;
  preConfigure = ''
    export PATH=${binutils}/tools/bin:${gccStage1}/tools/bin:$PATH;
    echo "rootsbindir=/usr/sbin" > configparms
    mkdir -p build && cd build
  '';
  configureScript = "../configure";
  configurePlatforms = [ ];
  configureFlags = [
    "--prefix=/usr"
    "--host="
  ];
}
