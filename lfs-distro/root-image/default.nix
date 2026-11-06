{ callPackage, nixpkgs, sysenv, etc }:

callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" {
    storePaths = [ sysenv etc ];
    volumeLabel = "lfs-root";
    populateImageCommands = ''
        mkdir -p ./files/usr ./files/root ./files/tmp ./files/proc ./files/sys ./files/dev
        ln -s ${sysenv}/bin  ./files/bin
        ln -s ${sysenv}/sbin ./files/sbin
        ln -s ${sysenv}/bin  ./files/usr/bin
        ln -s ${etc}         ./files/etc
    '';
}
