{ stdenv, fetchurl, texinfo, perl, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-final-binutils";
    version = "2.43";

    src = fetchurl {
        url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
        hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
    };

    # texinfo: as in step 8b. perl: pod2man makes the man pages.
    nativeBuildInputs = [ texinfo perl ];

    # LFS builds in a separate directory.
    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";

    # stdenv adds --build and --host with the nixpkgs name of the machine.
    # Give the three names yourself, all the same: the tools are native.
    configurePlatforms = [ ];
    configureFlags = [
        "--build=${triple}"
        "--host=${triple}"
        "--target=${triple}"
        "--disable-nls"
        "--disable-werror"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu"
    ];
}
