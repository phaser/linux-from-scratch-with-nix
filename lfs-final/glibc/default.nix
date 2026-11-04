# Step 11, stage 1: glibc again, built by lfsStdenv (your gcc, your tools).
# Same source and flags as lfs-temp/glibc, but native: no --host, no PATH.
{ stdenv, fetchurl, bison, python3, perl, headers }:

stdenv.mkDerivation rec {
    pname = "lfs-final-glibc";
    version = "2.40";

    src = fetchurl {
        url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
        hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
    };

    # The loader reads $out/etc/ld.so.cache, not the /etc/ld.so.cache of the
    # host. The patch in the pinned nixpkgs is for glibc 2.44 and does not
    # apply; this is the last version, the one nixpkgs used with glibc 2.40.
    patches = [
        (fetchurl {
            url = "https://raw.githubusercontent.com/NixOS/nixpkgs/acdcb8566ae560752a8a1ce3aacc617a3da6cdd5/pkgs/development/libraries/glibc/dont-use-system-ld-so-cache.patch";
            hash = "sha256-tsJKNF7QB3q+RvPlCWh7GKb2nECEESd4gwNjCjkespE=";
        })
    ];

    # Build tools from nixpkgs. They run only during the build.
    nativeBuildInputs = [ bison python3 perl ];

    # As nixpkgs: glibc sets these itself, per file. --enable-stack-protector
    # gives the protector to the files that can have it.
    hardeningDisable = [ "fortify" "stackprotector" "strictflexarrays3" ];
    env = {
        NIX_NO_SELF_RPATH = true;   # no -rpath $out/lib
        BASH_SHELL = "/bin/sh";     # else scripts store the path of lfs-temp-bash
    };

    preConfigure = "mkdir -p build && cd build";
    configureScript = "../configure";
    configureFlags = [
        "--enable-kernel=4.19"
        "--with-headers=${headers}/usr/include"
        "--disable-nscd"
        "--enable-stack-protector=strong"
    ];

    # As nixpkgs: after configure (its tests need the normal link), stop the
    # ld-wrapper adding -rpath <lfs-temp-glibc>/lib to every library.
    # The programs that run during the build still need that rpath.
    postConfigure = "export NIX_DONT_SET_RPATH=1";
    makeFlags = [ "BUILD_LDFLAGS=-Wl,-rpath,${stdenv.cc.libc}/lib" ];

    postInstall = ''
        # make install runs ldconfig. The patched loader would read this cache.
        rm -f $out/etc/ld.so.cache
        for d in ${headers}/usr/include/*; do
            [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
        done
    '';
}
