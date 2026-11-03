{ lib, fetchurl, mkTemp }:

mkTemp rec {
    pname = "gnumake";
    version = "4.4.1";

    src = fetchurl {
        url = "mirror://gnu/make/make-${version}.tar.gz";
        hash = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
    };

    # LFS chapter 6
    configureFlags = [ "--without-guile" ];
}

