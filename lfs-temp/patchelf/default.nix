{ fetchurl, mkTemp }:

mkTemp rec {
    pname = "patchelf";
    version = "0.18.0";

    src = fetchurl {
        url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
        hash = "sha256-GVKyp4K6V2J5whHulC40F0j9tEmX9wTdU970bNBVRws=";
    };
}
