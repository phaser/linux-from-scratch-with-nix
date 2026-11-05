{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-bzip2";
    version = "1.0.8";

    src = fetchurl {
        url = "https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz";
        hash = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    };

    # No configure script. The Makefile uses gcc, ar and ranlib from PATH.
    makeFlags = [ "PREFIX=$(out)" ];
}
