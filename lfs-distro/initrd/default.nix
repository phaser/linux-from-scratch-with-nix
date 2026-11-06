{ makeInitrd, init, sysenv, etc }:

makeInitrd {
    name = "lfs-initrd";
    contents = [
        { object = init;                 symlink = "/init"; }
        { object = "${sysenv}/bin";      symlink = "/bin"; }
        { object = "${sysenv}/sbin";     symlink = "/sbin"; }
        { object = "${sysenv}/bin";      symlink = "/usr/bin"; }
        { object = etc;                  symlink = "/etc"; }
    ];
}
