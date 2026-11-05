{ stdenv, triple, binutils, gccStage2 }:
{ pname, ... }@args:
stdenv.mkDerivation (args // {
  pname = "lfs-temp-${pname}";
  configurePlatforms = [ ];
  configureFlags = [ "--host=${triple}" "--build=${stdenv.buildPlatform.config}" ]
    ++ (args.configureFlags or [ ]);
  preConfigure = ''
    export PATH=${gccStage2}/tools/bin:${binutils}/tools/bin:$PATH
    unset CC CXX AR AS LD NM OBJCOPY OBJDUMP READELF
    export STRIP=${triple}-strip RANLIB=${triple}-ranlib
  '' + (args.preConfigure or "");
  LDFLAGS = "-static";
  dontPatchShebangs = true;  # else scripts get the host bash
})
