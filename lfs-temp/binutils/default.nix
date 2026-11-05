# Step 8b: the step 1 file, changed as the table says.
{ lib, fetchurl, texinfo, mkTemp, triple }:

mkTemp rec {
    pname = "binutils";
    version = "2.43";

    src = fetchurl {
        url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
        hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
    };

    nativeBuildInputs = [ texinfo ];

    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";

    configureFlags = [
        "--target=${triple}"
        "--disable-nls"
        "--disable-werror"
        "--disable-shared"
        "--disable-plugins"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu"
    ];

    preBuild = "make configure-host";
    makeFlags = [ "LDFLAGS=-all-static" ];

    meta.platforms = lib.platforms.linux;
}
