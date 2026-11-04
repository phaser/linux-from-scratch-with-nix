# Step 10: the first package that lfsStdenv builds.
# flake.nix gives stdenv = lfsStdenv. Without that, callPackage gives the
# nixpkgs stdenv, and this file builds a normal nixpkgs hello.
{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-hello";
    version = "2.12.3";

    # A fixed-output derivation: Nix checks the hash, so it does not matter
    # which stdenv downloads the file. Nothing of it stays in the closure.
    src = fetchurl {
        url = "mirror://gnu/hello/hello-${version}.tar.gz";
        hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
    };

    # Run `make check`: the tests run the new binary with your glibc.
    doCheck = true;
}
