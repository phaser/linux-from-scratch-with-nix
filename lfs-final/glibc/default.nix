{ stdenv, fetchurl, bison, python3, perl, headers }:

stdenv.mkDerivation rec {
  pname = "lfs-final-glibc";
  version = "2.40";

  src = fetchurl {
    url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
    hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
  };

  patches = [
    (fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/acdcb8566ae560752a8a1ce3aacc617a3da6cdd5/pkgs/development/libraries/glibc/dont-use-system-ld-so-cache.patch";
      hash = "sha256-tsJKNF7QB3q+RvPlCWh7GKb2nECEESd4gwNjCjkespE=";
    })
  ];

  nativeBuildInputs = [ bison python3 perl ];

  hardeningDisable = [ "fortify" "stackprotector" "strictflexarrays3" ];
  env = {
    NIX_NO_SELF_RPATH = true;
    BASH_SHELL = "/bin/sh";
  };

  preConfigure = "mkdir -p build && cd build";
  configureScript = "../configure";
  configureFlags = [
    "--enable-kernel=4.19"
    "--with-headers=${headers}/usr/include"
    "--disable-nscd"
    "--enable-stack-protector=strong"
  ];

  postConfigure = "export NIX_DONT_SET_RPATH=1";
  makeFlags = [ "BUILD_LDFLAGS=-Wl,-rpath,${stdenv.cc.libc}/lib" ];

  postInstall = ''
    rm -f $out/etc/ld.so.cache
    for d in ${headers}/usr/include/*; do
      [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
    done
  '';
}
