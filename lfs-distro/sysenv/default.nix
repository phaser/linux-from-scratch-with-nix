{ lib, buildEnv, final, busybox, cc }:

buildEnv {
    name = "lfs-final-sysenv";

    paths = with final; [
        bash coreutils findutils gnugrep gnused gawk
        gnutar gzip xz gnumake diffutils gnupatch

        cc
        binutils

        (lib.lowPrio busybox)
    ];

    # link only bin/ and sbin/, not include/, share/, lib/ ...
    pathsToLink = [ "/bin" "/sbin" ];
}
