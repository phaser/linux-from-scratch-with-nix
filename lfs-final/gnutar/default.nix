{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-gnutar";
    version = "1.35";

    src = fetchurl {
        url = "mirror://gnu/tar/tar-${version}.tar.xz";
        hash = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
    };
}
