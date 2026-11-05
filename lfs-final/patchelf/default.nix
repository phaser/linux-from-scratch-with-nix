{ stdenv, fetchurl, path }:

stdenv.mkDerivation rec {
    pname = "lfs-final-patchelf";
    version = "0.18.0";

    src = fetchurl {
        url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
        hash = "sha256-GVKyp4K6V2J5whHulC40F0j9tEmX9wTdU970bNBVRws=";
    };

    # As in step 7: the nixpkgs hook, patchelf --shrink-rpath in the fixup
    # phase. path = the nixpkgs source, from callPackage.
    setupHook = "${path}/pkgs/development/tools/misc/patchelf/setup-hook.sh";
}
