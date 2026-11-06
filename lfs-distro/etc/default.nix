{ runCommand }:

runCommand "lfs-final-etc" { } ''
  mkdir -p $out

  echo 'root:x:0:0:root:/root:/bin/bash' > $out/passwd
  echo 'root:x:0:'                       > $out/group
  echo 'lfs'                             > $out/hostname

  cat > $out/profile <<'EOF'
  export PATH=/bin:/sbin
  PS1='\u@\h:\w\$ '
  EOF

  cat > $out/inittab <<'EOF'
  ::sysinit:/etc/rc
  ttyAMA0::respawn:-/bin/bash -l
  ::ctrlaltdel:/sbin/reboot
  ::shutdown:/bin/umount -a -r
  EOF

  cat > $out/rc <<'EOF'
  #!/bin/sh
  mkdir -p /proc /sys /dev /tmp /root
  mountpoint -q /proc || mount -t proc proc /proc
  mountpoint -q /sys  || mount -t sysfs sysfs /sys
  mountpoint -q /dev  || mount -t devtmpfs devtmpfs /dev
  hostname -F /etc/hostname
  echo "lfs: rc done"
  EOF
  chmod 0755 $out/rc
''
