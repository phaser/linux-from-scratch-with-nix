{ runCommand, headers, glibc }:

runCommand "lfs-sysroot" { } ''
    mkdir -p $out
    cp -r ${headers}/. $out/
    chmod -R u+w $out
    cp -r ${glibc}/. $out/
''
