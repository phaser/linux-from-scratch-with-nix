{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "lfs-hello";
  version = "2.12.3";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-${version}.tar.gz";
    hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
  };

  doCheck = true;
}
