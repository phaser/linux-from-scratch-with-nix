{ fetchurl, mkTemp }:

mkTemp rec {
    pname = "gawk";
    version = "5.3.0";

    src = fetchurl {
        url = "mirror://gnu/gawk/gawk-${version}.tar.xz";
        hash = "sha256-ypwW09EdD/jGnXncC0cmfhMppps5t5mJVgTtRH08qQs=";
    };

    postPatch = "sed -i 's/extras//' Makefile.in";
}
