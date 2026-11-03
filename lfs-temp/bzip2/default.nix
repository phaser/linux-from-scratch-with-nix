{ fetchurl, mkTemp, triple }:

mkTemp rec {
    pname = "bzip2";
    version = "1.0.8";

    src = fetchurl {
        url = "https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz";
        hash = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    };

    # No configure script. Do not set dontConfigure: it also skips the
    # helper's preConfigure (8).
    makeFlags = [
        "CC=${triple}-gcc" "AR=${triple}-ar" "RANLIB=${triple}-ranlib"
        "PREFIX=$(out)" "LDFLAGS=-static"
    ];
}
