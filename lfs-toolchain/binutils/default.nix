{ lib, stdenv, fetchurl, texinfo, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-binutils";
    version = "2.43";

    src = fetchurl {
        url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
        hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
    };

    # The build regenerates the bfd manual's .texi inputs, so make rebuilds
    # bfd.info and needs makeinfo. LFS lists Texinfo as a host requirement.
    nativeBuildInputs = [ texinfo ];

    dontAddPrefix = true;
    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";

    configureFlags = [
        "--target=${triple}"
        "--prefix=${placeholder "out"}/tools"
        "--disable-nls"
        "--disable-werror"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu"
    ];

    meta = {
        description = "binutils for ${triple}, built from source";
        platforms = lib.platforms.linux;
    };
}
