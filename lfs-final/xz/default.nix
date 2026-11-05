{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-xz";
    version = "5.6.2";

    src = fetchurl {
        url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.xz";
        hash = "sha256-qds7s9ZOJIoPrpY/j7a6hRomuhgi5QTcDv0YqAxibK8=";
    };

    configureFlags = [ "gl_cv_posix_shell=/bin/sh" ];    # Nix (5)
}
