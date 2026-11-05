{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-gzip";
    version = "1.13";

    src = fetchurl {
        url = "mirror://gnu/gzip/gzip-${version}.tar.xz";
        hash = "sha256-dFTraTXbF8ZlVXbC4bD6vv04tNCTbg+H9IzQYs6RoFc=";
    };

    configureFlags = [ "ac_cv_path_GREP=grep" ];         # Nix (6)
    makeFlags = [ "SHELL=/bin/sh" ];                     # Nix (5)
}
