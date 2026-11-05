{ fetchurl, mkTemp }:

mkTemp rec {
  pname = "gnused";
  version = "4.9";

  src = fetchurl {
    url = "mirror://gnu/sed/sed-${version}.tar.xz";
    hash = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
  };
}
