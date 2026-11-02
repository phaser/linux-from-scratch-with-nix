{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-linux-headers";
    version = "6.12";

    src = fetchurl {
        url = "http://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
        hash = "sha256-saJWK+VuQq+z+EidTCp6xHKsIwmPHvHB5A2mAfVGJes=";
    };

    dontConfigure = true;

    buildPhase = ''
        runHook preBuild
        make mrproper
        make headers
        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall
        find usr/include -type f ! -name '*.h' -delete
        mkdir -p $out/usr/include
        cp -r usr/include/. $out/usr/include
        runHook postInstall
    '';

    meta = {
        description = "Linux ${version} userspace headers";
        platforms = lib.platforms.linux;
    };
}
