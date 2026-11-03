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
        in toolchain // {
            temp = import ./lfs-temp { inherit pkgs toolchain; };
            lfstoolchain = import ./lfs-toolchain { inherit pkgs; };
      };
    };
}
