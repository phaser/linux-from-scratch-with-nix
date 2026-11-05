{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-diffutils";
    version = "3.10";

    src = fetchurl {
        url = "mirror://gnu/diffutils/diffutils-${version}.tar.xz";
        hash = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
    };

    configureFlags = [ "ac_cv_path_PR_PROGRAM=" ];       # Nix (6)
}
