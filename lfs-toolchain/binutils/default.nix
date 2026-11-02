{ lib, stdenv, fetchurl, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-binutils";
    version = "2.43";

    src = fetchurl {
        url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
        hash = lib.fakeHash;
    };

    dontAddPrefix = true;
    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";

    configureFlags = [
        "--target=${triple}"
        "--prefix=${placeholder "out"}/tools"
        "--disable-nls"
        "--disable-werror"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu0"
    ];

    meta = {
        description = "binutils for ${triple}, built from source";
        platforms = lib.platforms.linux;
    };
}
