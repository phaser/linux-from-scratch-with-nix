{ lib, stdenv, fetchurl }:

# Rung 3 — Linux kernel headers.
#
# glibc needs to know the shape of the kernel's syscall interface. LFS
# installs the headers to $LFS/usr/include; here they go to their own store
# path, and rung 4 composes them with glibc into one sysroot.
#
# Check after building:
#   ls $out/usr/include/linux/ | head
#   ls $out/usr/include/asm/   | head     # the arch-specific ones

stdenv.mkDerivation rec {
  pname = "lfs-linux-headers";
  version = "6.12";

  src = fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
    hash = lib.fakeHash;
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
    # LFS deletes everything that is not a header, before installing.
    find usr/include -type f ! -name '*.h' -delete
    mkdir -p $out/usr/include
    cp -r usr/include/. $out/usr/include/
    runHook postInstall
  '';

  meta = {
    description = "Linux ${version} userspace headers";
    platforms = lib.platforms.linux;
  };
}
