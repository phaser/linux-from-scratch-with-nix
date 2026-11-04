{
  description = "my-linux-distro — bootstrap a Linux toolchain from source, LFS-style, with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # The platform these derivations build *on* and *for*.
      # Everything here is native-but-staged, exactly like LFS pass 1:
      # build = host = target architecture, but a distinct vendor triple.
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      legacyPackages.${system} = 
        let
            toolchain = import ./lfs-toolchain { inherit pkgs; };
        in toolchain // rec {
            lfstoolchain = import ./lfs-toolchain { inherit pkgs; };
            temp = import ./lfs-temp { inherit pkgs toolchain; };
            lfsStdenv = import ./lfs-stdenv { inherit pkgs nixpkgs temp; };
            hello = pkgs.callPackage ./lfs-stdenv/hello { stdenv = lfsStdenv; };
            final = import ./lfs-final { inherit pkgs toolchain lfsStdenv; };
      };
    };
}
