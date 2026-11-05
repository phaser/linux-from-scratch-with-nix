{ fetchurl, mkTemp }:

mkTemp rec {
  pname = "xz";
  version = "5.6.2";

  src = fetchurl {
    url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.xz";
    hash = "sha256-qds7s9ZOJIoPrpY/j7a6hRomuhgi5QTcDv0YqAxibK8=";
  };

  configureFlags = [
    "--disable-shared"                                   # static (7)
    "gl_cv_posix_shell=/bin/sh"                          # Nix (5)
  ];
  makeFlags = [ "LDFLAGS=-all-static" ];                 # static (7)
}
