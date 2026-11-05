{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-gnupatch";
    version = "2.7.6";

    src = fetchurl {
        url = "mirror://gnu/patch/patch-${version}.tar.xz";
        hash = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
    };
}
