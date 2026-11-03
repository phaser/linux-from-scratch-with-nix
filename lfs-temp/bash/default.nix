{ fetchurl, mkTemp }:

mkTemp rec {
    pname = "bash";
    version = "5.2.32";

    src = fetchurl {
        url = "mirror://gnu/bash/bash-${version}.tar.gz";
        hash = "sha256-0++A0rZ9jLvk0yZcY6csRvmyeOrW4OBtYYAbWPI/ULU=";
    };

    configureFlags = [ "--without-bash-malloc" "bash_cv_strtold_broken=no" ];
    preConfigure = ''
        export CC_FOR_BUILD="gcc -std=gnu17"
        export CFLAGS="-g -O2 -fpermissive"
    '';
}
