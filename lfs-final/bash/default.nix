{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "lfs-final-bash";
    version = "5.2.32";

    src = fetchurl {
        url = "mirror://gnu/bash/bash-${version}.tar.gz";
        hash = "sha256-0++A0rZ9jLvk0yZcY6csRvmyeOrW4OBtYYAbWPI/ULU=";
    };

    configureFlags = [ "--without-bash-malloc" ];        # LFS
    # gcc 14 makes some old C errors. As in step 7.
    preConfigure = ''
        export CFLAGS="-g -O2 -fpermissive"
    '';
    postInstall = ''
        # LFS: ln -sv bash /bin/sh. The stdenv fixup (audit-tmpdir) runs `sh`.
        ln -s bash $out/bin/sh

        # lib/bash/Makefile.inc (for loadable builtins) stores the path of
        # install. On PATH, the first install is the nixpkgs coreutils (the
        # cc-wrapper leak of step 9). Keep only the name. Do not give configure
        # ac_cv_path_install=install: a name without a slash becomes ../install
        # in the subdirectories, and make install skips files.
        sed -i 's|^INSTALL = .*/install|INSTALL = install|' $out/lib/bash/Makefile.inc
    '';
}
