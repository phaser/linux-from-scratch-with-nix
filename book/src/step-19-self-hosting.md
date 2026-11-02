# Step 19 — the system builds a program (milestone 4)

The image contains the wrapped gcc from step 16. Use it inside the guest.

**Verify inside the guest:**

```console
# cat > /tmp/ver.c <<'EOF'
#include <stdio.h>
#include <gnu/libc-version.h>
int main(void) { printf("glibc %s\n", gnu_get_libc_version()); return 0; }
EOF
# gcc /tmp/ver.c -o /tmp/ver && /tmp/ver     # glibc 2.40
# readelf -l /tmp/ver | grep interpreter     # .../lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
# gcc --version | head -1                     # gcc (GCC) 14.2.0
```

**This is milestone 4:** the distro boots from its own disk and compiles and
runs a program by itself.
