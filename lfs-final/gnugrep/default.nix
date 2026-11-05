{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-gnugrep";
    version = "3.11";

    src = fetchurl {
        url = "mirror://gnu/grep/grep-${version}.tar.xz";
        hash = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
    };

    makeFlags = [ "SHELL=/bin/sh" ];                     # Nix (5)
}
