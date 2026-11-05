{ stdenv, src, version, bc, bison, flex, perl, openssl }:

stdenv.mkDerivation {
    pname = "lfs-final-linux";
    inherit src version;

    nativeBuildInputs = [ bc bison flex perl openssl ];

    hardeningDisable = [ "all" ];

    postPatch = "patchShebangs scripts";

    KBUILD_BUILD_USER = "lfs";
    KBUILD_BUILD_HOST = "lfs";
    KBUILD_BUILD_TIMESTAMP = "1970-01-01";

    configurePhase = ''
        runHook preConfigure
        make ARCH=arm64 defconfig
        runHook postConfigure
    '';

    buildPhase = ''
        runHook preBuild
        make ARCH=arm64 -j$NIX_BUILD_CORES Image
        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp arch/arm64/boot/Image $out/Image
        cp .config $out/config
        runHook postInstall
    '';
}
