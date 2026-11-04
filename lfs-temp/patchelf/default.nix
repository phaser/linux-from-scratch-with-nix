{ fetchurl, mkTemp, path }:

mkTemp rec {
    pname = "patchelf";
    version = "0.18.0";

    src = fetchurl {
        url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
        hash = "sha256-GVKyp4K6V2J5whHulC40F0j9tEmX9wTdU970bNBVRws=";
    };

    # The nixpkgs hook: patchelf --shrink-rpath on every ELF file in the
    # fixup phase. lfsStdenv (step 9) uses it, as nixpkgs does with its patchelf.
    # path = the nixpkgs source, from callPackage.
    setupHook = "${path}/pkgs/development/tools/misc/patchelf/setup-hook.sh";
}
