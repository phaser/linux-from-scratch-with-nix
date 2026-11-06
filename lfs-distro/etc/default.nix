{ runCommand }:

runCommand "lfs-final-etc" { } ''
  mkdir -p $out
  echo 'root:x:0:0:root:/root:/bin/bash' > $out/passwd
  # ... the other files of the table
  cat > $out/rc <<'EOF'
  #!/bin/sh
  # ... the rc script above
  EOF
  chmod 0755 $out/rc
''
