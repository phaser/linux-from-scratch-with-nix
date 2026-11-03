{ stdenv, triple, binutils, gccStage2 }:
{ pname, ...}@args:
stdenv.mkDerivation (args // {
    pname = "lfs-temp-${pname}";
    configurePlatforms = [ ];
    configureFlags = [ "--host=${triple}" "--build=${stdenv.buildPlatform.config}" ] ++ (args.configureFlags or [ ]);
    preConfigure = ''
        export PATH=${gccStage2}/tools/bin:${binutils}/tools/bin:$PATH
        # stdenv exports CC=gcc (the host gcc), AR=ar, and others. configure
        # uses them instead of ${triple}-gcc. Unset them. The fixup phase
        # strips with $STRIP and $RANLIB; the debug info holds store paths of the toolchain.
        unset CC CXX AR AS LD NM OBJCOPY OBJDUMP READELF
        export STRIP=${triple}-strip RANLIB=${triple}-ranlib
    '' + (args.preConfigure or "");
    LDFLAGS = "-static";
    # Keep #!/bin/sh in scripts. patchShebangs would point them at the host bash.
    dontPatchShebangs = true;
})
