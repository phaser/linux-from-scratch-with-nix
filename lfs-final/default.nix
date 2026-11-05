# Step 11: every package again, built by your own stdenvs.
{ pkgs, nixpkgs, toolchain, temp, lfsStdenv }:

let
    mkStdenv = args: import ../lfs-stdenv ({ inherit pkgs nixpkgs temp; } // args);
in rec {
    # Stage 1: built by lfsStdenv.
    glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };

    lfsStdenvFinalGlibc = mkStdenv { name = "lfs-stdenv-final-glibc"; libc = glibc; };

    binutils = pkgs.callPackage ./binutils { stdenv = lfsStdenvFinalGlibc; inherit (toolchain) triple; };
    gcc = pkgs.callPackage ./gcc { stdenv = lfsStdenvFinalGlibc; inherit glibc; inherit (toolchain) triple; };


    # The final glibc, binutils and gcc. The other tools are still lfs-temp-*.
    lfsStdenvFinalToolchain = mkStdenv {
        name = "lfs-stdenv-final-toolchain";
        libc = glibc;
        inherit binutils gcc;
    };

    # Sample compilation 2.
    helloFinalToolchain = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalToolchain; };

    # Stage 3: built by lfsStdenvFinalToolchain.
    coreutils = pkgs.callPackage ./coreutils { stdenv = lfsStdenvFinalToolchain; };
    gnumake = pkgs.callPackage ./gnumake { stdenv = lfsStdenvFinalToolchain; };
}
