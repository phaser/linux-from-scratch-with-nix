{ fetchurl, mkTemp }:

mkTemp rec {
    pname = "gnupatch";
    version = "2.7.6";

    src = fetchurl {
        url = "mirror://gnu/patch/patch-${version}.tar.xz";
        hash = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
    };

    configureFlags = [ "gl_cv_func_working_mktime=yes" ];
}
