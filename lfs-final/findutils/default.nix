{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-findutils";
    version = "4.10.0";

    src = fetchurl {
        url = "mirror://gnu/findutils/findutils-${version}.tar.xz";
        hash = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
    };

    configureFlags = [ "ac_cv_path_SORT=sort" ];         # Nix (6)
}
