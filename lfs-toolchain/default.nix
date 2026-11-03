{ pkgs }:

let
  inherit (pkgs) callPackage linkFarm;
  triple = "aarch64-lfs-linux-gnu";
  
  binutils = callPackage ./binutils { inherit triple; };
  gccStage1 = callPackage ./gcc-stage1 { inherit triple binutils; };
  headers = callPackage ./linux-headers { };
  glibc = callPackage ./glibc { inherit triple binutils gccStage1 headers; };
  sysroot = callPackage ./sysroot { inherit headers glibc; };
  gccStage2 = callPackage ./gcc-stage2 { inherit triple binutils sysroot; };
in
{
    inherit binutils gccStage1 headers glibc sysroot gccStage2;

    toolchain = linkFarm "lfs-toolchain" [
        { name = "binutils"; path = binutils; }
        { name = "gccStage1"; path = gcc-stage1; }
        { name = "linux-headers"; path = headers; }
        { name = "glibc"; path = glibc; }
        { name = "sysroot"; path = sysroot; }
        { name = "gccStage2"; path = gcc-stage2; }
    ];
}

