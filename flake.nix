{
  description = "my-linux-distro — bootstrap a Linux toolchain from source, LFS-style, with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      # legacyPackages, not packages: legacyPackages can nest (.#temp.gnumake).
      # Later steps add lfs-temp, lfs-stdenv, lfs-final and lfs-distro here.
      legacyPackages.${system} =
        let toolchain = import ./lfs-toolchain { inherit pkgs; };
        in toolchain // rec {
          temp = import ./lfs-temp { inherit pkgs toolchain; };
          lfsStdenv = import ./lfs-stdenv { inherit pkgs nixpkgs temp; };
          hello = pkgs.callPackage ./lfs-stdenv/hello { stdenv = lfsStdenv; };
          final = import ./lfs-final { inherit pkgs nixpkgs toolchain temp lfsStdenv; };
          lfsStdenvFinal = import ./lfs-stdenv-final { inherit pkgs nixpkgs temp final; };
          helloFinal = (pkgs.callPackage ./lfs-stdenv/hello { stdenv = lfsStdenvFinal; })
              .overrideAttrs { pname = "lfs-final-hello"; };
          distro = import ./lfs-distro { inherit pkgs nixpkgs toolchain final lfsStdenvFinal; };
          inherit (distro) kernel;
        };
    };
}
