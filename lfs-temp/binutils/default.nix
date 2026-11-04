{ fetchurl, texinfo, mkTemp, triple }:

mkTemp rec {
    pname = "binutils";
    version = "2.43";

    src = fetchurl {
        url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
        hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
    };

    # The build regenerates the bfd manual's .texi inputs, so make rebuilds
    # bfd.info and needs makeinfo. LFS lists Texinfo as a host requirement.
    nativeBuildInputs = [ texinfo ];

    # mkTemp gives --host=${triple}. With --target the same, the tools are
    # native: bin/ld, not bin/${triple}-ld. A static ld cannot load plugins,
    # and gprofng needs shared libraries.
    configureFlags = [
        "--target=${triple}"
        "--disable-nls"
        "--disable-werror"
        "--disable-shared"
        "--disable-plugins"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu"
    ];

    # libtool links the programs, and it removes -static (the mkTemp LDFLAGS):
    # for libtool, -static means "no shared libtool libraries" only. Its flag
    # for a static program is -all-static. gcc does not know -all-static, so
    # the configure scripts must not see it. The top level configures each
    # subdirectory during make, so configure them all first.
    preBuild = "make configure-host";
    makeFlags = [ "LDFLAGS=-all-static" ];
}
