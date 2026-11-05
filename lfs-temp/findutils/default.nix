{ fetchurl, mkTemp }:

mkTemp rec {
  pname = "findutils";
  version = "4.10.0";

  src = fetchurl {
    url = "mirror://gnu/findutils/findutils-${version}.tar.xz";
    hash = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
  };

  configureFlags = [
    "gl_cv_func_working_mktime=yes"                      # static (2)
    "ac_cv_path_SORT=sort"                               # Nix (6)
  ];
}
