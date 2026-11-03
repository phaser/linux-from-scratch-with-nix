{ fetchurl, mkTemp }:

mkTemp rec {
    pname = "gnutar";
    version = "1.35";

    src = fetchurl {
        url = "mirror://gnu/tar/tar-${version}.tar.xz";
        hash = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
    };

    configureFlags = [ "gl_cv_func_working_mktime=yes" ];
}
