{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-coreutils";
    version = "9.5";

    src = fetchurl {
        url = "mirror://gnu/coreutils/coreutils-${version}.tar.xz";
        hash = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
    };

    configureFlags = [
        "--enable-install-program=hostname"          # LFS
        "--enable-no-install-program=kill,uptime"    # LFS
    ];
}

