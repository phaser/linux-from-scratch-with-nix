{ writeScript, final }:

writeScript "lfs-final-init" ''
    #!${final.bash}/bin/bash
   
    mkdir -p /dev
    mount -t devtmpfs devtmpfs /dev
    exec </dev/console >/dev/console 2>&1
    exec /sbin/init
''
